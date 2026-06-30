import {SecretManagerServiceClient} from "@google-cloud/secret-manager";
import * as admin from "firebase-admin";
import {onRequest} from "firebase-functions/v2/https";
import {onSchedule} from "firebase-functions/v2/scheduler";
import {PKPass, type Barcode} from "passkit-generator";
import {v4 as uuid} from "uuid";

admin.initializeApp();

const secrets = new SecretManagerServiceClient();
const bucket = () => admin.storage().bucket();

type BarcodeFormat = "qr" | "code128" | "pdf417" | "aztec" | string;

interface GeneratePassRequest {
  cardId: string;
  locale: string;
  card: {
    type: string;
    title: string;
    subtitle?: string;
    barcode?: {
      value: string;
      format: BarcodeFormat;
      altText?: string;
      walletExportFormat?: BarcodeFormat;
    };
    design: {
      backgroundColorHex: string;
      foregroundColorHex: string;
      labelColorHex: string;
    };
    fields: Array<{ key: string; label: string; value: string }>;
    backFields: Array<{ key: string; label: string; value: string }>;
    relevantDate?: string | null;
    expiryDate?: string | null;
  };
  logoStoragePath?: string;
}

export const generatePass = onRequest({cors: false}, async (req, res) => {
  if (req.method !== "POST") {
    res.status(405).send("Method not allowed");
    return;
  }

  const uid = await requireFirebaseUser(req);
  const body = req.body as GeneratePassRequest;
  assertOwnerPath(uid, body.logoStoragePath);

  const serialNumber = uuid();
  const passTypeIdentifier = await secretText("PASS_TYPE_IDENTIFIER");
  const teamIdentifier = await secretText("APPLE_TEAM_ID");
  const certificates = await loadCertificates();

  const pass = await PKPass.from(
    {
      model: passModel(body.card.type),
      certificates
    },
    {
      serialNumber,
      passTypeIdentifier,
      teamIdentifier,
      organizationName: "Passly",
      description: body.card.title,
      backgroundColor: body.card.design.backgroundColorHex,
      foregroundColor: body.card.design.foregroundColorHex,
      labelColor: body.card.design.labelColorHex
    }
  );

  pass.type = walletPassStyle(body.card.type);
  pass.primaryFields.push({key: "title", label: body.card.subtitle ?? "PASS", value: body.card.title});
  for (const field of body.card.fields.slice(0, 4)) {
    pass.secondaryFields.push({key: field.key, label: field.label, value: field.value});
  }
  for (const field of body.card.backFields) {
    pass.backFields.push({key: field.key, label: field.label, value: field.value});
  }
  if (body.card.barcode?.value) {
    const barcode: Barcode = {
      message: body.card.barcode.value,
      format: walletBarcodeFormat(body.card.barcode.walletExportFormat ?? body.card.barcode.format),
      messageEncoding: "iso-8859-1",
      altText: body.card.barcode.altText ?? body.card.barcode.value
    };
    pass.setBarcodes(barcode);
  }

  const buffer = pass.getAsBuffer();
  const storagePath = `users/${uid}/cards/${body.cardId}/generated/${serialNumber}.pkpass`;
  await bucket().file(storagePath).save(buffer, {
    contentType: "application/vnd.apple.pkpass",
    resumable: false,
    metadata: {cacheControl: "private, max-age=300"}
  });
  const [downloadUrl] = await bucket().file(storagePath).getSignedUrl({
    action: "read",
    expires: Date.now() + 15 * 60 * 1000
  });

  await admin.firestore().doc(`users/${uid}/passJobs/${serialNumber}`).set({
    cardId: body.cardId,
    status: "complete",
    downloadPath: storagePath,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    updatedAt: admin.firestore.FieldValue.serverTimestamp()
  });

  res.json({
    passId: serialNumber,
    serialNumber,
    passTypeIdentifier,
    storagePath,
    downloadUrl
  });
});

export const updatePass = generatePass;

export const deleteGeneratedPass = onRequest({cors: false}, async (req, res) => {
  const uid = await requireFirebaseUser(req);
  const {storagePath} = req.body as {storagePath?: string};
  assertOwnerPath(uid, storagePath);
  if (storagePath) {
    await bucket().file(storagePath).delete({ignoreNotFound: true});
  }
  res.json({ok: true});
});

export const cleanupGeneratedPasses = onSchedule("every 24 hours", async () => {
  const [files] = await bucket().getFiles({prefix: "users/"});
  const cutoff = Date.now() - 7 * 24 * 60 * 60 * 1000;
  await Promise.all(files
    .filter((file) => file.name.includes("/generated/") && Date.parse(String(file.metadata.updated)) < cutoff)
    .map((file) => file.delete({ignoreNotFound: true})));
});

async function requireFirebaseUser(req: {header(name: string): string | undefined}): Promise<string> {
  const header = req.header("Authorization") ?? "";
  const match = header.match(/^Bearer (.+)$/);
  if (!match) {
    throw new Error("Missing auth token");
  }
  const decoded = await admin.auth().verifyIdToken(match[1]);
  return decoded.uid;
}

function assertOwnerPath(uid: string, storagePath?: string): void {
  if (storagePath && !storagePath.startsWith(`users/${uid}/`)) {
    throw new Error("Forbidden storage path");
  }
}

function walletBarcodeFormat(format: BarcodeFormat): Barcode["format"] {
  switch (format) {
    case "code128": return "PKBarcodeFormatCode128";
    case "pdf417": return "PKBarcodeFormatPDF417";
    case "aztec": return "PKBarcodeFormatAztec";
    default: return "PKBarcodeFormatQR";
  }
}

function walletPassStyle(type: string): "generic" | "coupon" | "storeCard" | "eventTicket" | "boardingPass" {
  if (type === "coupon") return "coupon";
  if (["loyalty", "store", "membership", "giftCard"].includes(type)) return "storeCard";
  if (["eventTicket", "movieTicket", "sportsTicket", "concertTicket"].includes(type)) return "eventTicket";
  if (type === "boardingReference") return "boardingPass";
  return "generic";
}

function passModel(_type: string): string {
  return "pass-model";
}

async function loadCertificates() {
  return {
    wwdr: await secretBuffer("APPLE_WWDR_CERTIFICATE_PEM"),
    signerCert: await secretBuffer("APPLE_PASS_CERTIFICATE_PEM"),
    signerKey: await secretBuffer("APPLE_PASS_PRIVATE_KEY_PEM"),
    signerKeyPassphrase: await secretText("APPLE_PASS_CERTIFICATE_PASSWORD")
  };
}

async function secretText(name: string): Promise<string> {
  const [version] = await secrets.accessSecretVersion({name: `projects/${process.env.GCLOUD_PROJECT}/secrets/${name}/versions/latest`});
  return version.payload?.data ? Buffer.from(version.payload.data).toString("utf8") : "";
}

async function secretBuffer(name: string): Promise<Buffer> {
  return Buffer.from(await secretText(name), "utf8");
}
