import * as admin from "firebase-admin";

import { numberValue, stringValue } from "./utils";

type ProcessingQuotaState = "reserved" | "applied" | "released";
type UserPlan = "freemium" | "premium" | "pro";

function totalCountForPlan(plan: UserPlan): number | null {
  switch (plan) {
    case "freemium":
      return 5;
    case "premium":
    case "pro":
      return null;
  }
}

function recordingLimitSecondsForPlan(plan: UserPlan): number {
  switch (plan) {
    case "freemium":
      return 5 * 60;
    case "premium":
      return 100 * 60;
    case "pro":
      return 4 * 60 * 60;
  }
}

function audioImportLimitSecondsForPlan(plan: UserPlan): number {
  switch (plan) {
    case "freemium":
      return 5 * 60;
    case "premium":
      return 100 * 60;
    case "pro":
      return 4 * 60 * 60;
  }
}

function pdfPageLimitForPlan(plan: UserPlan): number {
  switch (plan) {
    case "freemium":
      return 5;
    case "premium":
      return 50;
    case "pro":
      return 200;
  }
}

function normalizePlan(value: unknown): UserPlan {
  const plan = stringValue(value);
  if (plan === "premium" || plan === "pro") {
    return plan;
  }

  return "freemium";
}

function normalizedQuota(data: admin.firestore.DocumentData | undefined): {
  plan: UserPlan;
  totalCount: number;
  usedCount: number;
  remainingCount: number;
  isUnlimited: boolean;
} {
  const plan = normalizePlan(data?.plan);
  const configuredTotalCount = totalCountForPlan(plan);
  const isUnlimited =
    typeof data?.processingLimitIsUnlimited === "boolean"
      ? Boolean(data.processingLimitIsUnlimited)
      : configuredTotalCount === null;
  const usedCount = Math.max(numberValue(data?.processingLimitUsedCount), 0);

  if (isUnlimited) {
    return {
      plan,
      totalCount: -1,
      usedCount,
      remainingCount: -1,
      isUnlimited: true,
    };
  }

  const totalCount = Math.max(
    numberValue(data?.processingLimitTotalCount) || configuredTotalCount || 0,
    0,
  );
  const clampedUsedCount = Math.min(usedCount, totalCount);
  const remainingCount = Math.max(totalCount - clampedUsedCount, 0);

  return {
    plan,
    totalCount,
    usedCount: clampedUsedCount,
    remainingCount,
    isUnlimited: false,
  };
}

function defaultUserProfileData(): admin.firestore.DocumentData {
  const plan: UserPlan = "freemium";
  const totalCount = totalCountForPlan(plan) ?? -1;
  return {
    plan,
    processingLimitTotalCount: totalCount,
    processingLimitUsedCount: 0,
    processingLimitRemainingCount: totalCount,
    processingLimitIsUnlimited: false,
    recordingLimitSec: recordingLimitSecondsForPlan(plan),
    audioImportLimitSec: audioImportLimitSecondsForPlan(plan),
    pdfPageLimit: pdfPageLimitForPlan(plan),
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  };
}

function parentUserReference(
  documentReference: admin.firestore.DocumentReference,
): admin.firestore.DocumentReference {
  const userReference = documentReference.parent.parent;

  if (!userReference) {
    throw new Error("User reference is unavailable for lecture document.");
  }

  return userReference;
}

export class ProcessingQuotaExceededError extends Error {
  constructor(
    readonly remainingCount: number,
  ) {
    super(
      `Not enough processing attempts left. Remaining: ${Math.max(remainingCount, 0)}.`,
    );
    this.name = "ProcessingQuotaExceededError";
  }
}

export async function reserveProcessingQuotaForLecture(
  documentReference: admin.firestore.DocumentReference,
): Promise<void> {
  const userReference = parentUserReference(documentReference);

  await admin.firestore().runTransaction(async transaction => {
    const [lectureSnapshot, userSnapshot] = await Promise.all([
      transaction.get(documentReference),
      transaction.get(userReference),
    ]);

    const lectureData = lectureSnapshot.data() ?? {};
    const quotaState = stringValue(lectureData.processingQuotaState);
    if (quotaState === "reserved" || quotaState === "applied") {
      return;
    }

    if (!userSnapshot.exists) {
      transaction.set(userReference, defaultUserProfileData(), { merge: true });
    }

    const quota = normalizedQuota(userSnapshot.data());
    if (!quota.isUnlimited && quota.remainingCount < 1) {
      throw new ProcessingQuotaExceededError(quota.remainingCount);
    }

    const usedCount = quota.usedCount + 1;
    const remainingCount = quota.isUnlimited
      ? -1
      : Math.max(quota.totalCount - usedCount, 0);

    transaction.set(
      userReference,
      {
        plan: quota.plan,
        processingLimitTotalCount: quota.totalCount,
        processingLimitUsedCount: usedCount,
        processingLimitRemainingCount: remainingCount,
        processingLimitIsUnlimited: quota.isUnlimited,
        recordingLimitSec: recordingLimitSecondsForPlan(quota.plan),
        audioImportLimitSec: audioImportLimitSecondsForPlan(quota.plan),
        pdfPageLimit: pdfPageLimitForPlan(quota.plan),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true },
    );

    transaction.set(
      documentReference,
      {
        processingQuotaState: "reserved" as ProcessingQuotaState,
        processingQuotaReservedAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true },
    );
  });
}

export async function finalizeProcessingQuotaForLecture(
  documentReference: admin.firestore.DocumentReference,
): Promise<void> {
  await admin.firestore().runTransaction(async transaction => {
    const lectureSnapshot = await transaction.get(documentReference);
    const lectureData = lectureSnapshot.data() ?? {};
    const quotaState = stringValue(lectureData.processingQuotaState);

    if (quotaState === "applied") {
      return;
    }

    if (quotaState !== "reserved") {
      return;
    }

    transaction.set(
      documentReference,
      {
        processingQuotaState: "applied" as ProcessingQuotaState,
        processingQuotaFinalizedAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true },
    );
  });
}

export async function releaseProcessingQuotaForLecture(
  documentReference: admin.firestore.DocumentReference,
): Promise<void> {
  const userReference = parentUserReference(documentReference);

  await admin.firestore().runTransaction(async transaction => {
    const [lectureSnapshot, userSnapshot] = await Promise.all([
      transaction.get(documentReference),
      transaction.get(userReference),
    ]);

    const lectureData = lectureSnapshot.data() ?? {};
    const quotaState = stringValue(lectureData.processingQuotaState);
    if (quotaState !== "reserved") {
      return;
    }

    const quota = normalizedQuota(userSnapshot.data());
    const usedCount = Math.max(quota.usedCount - 1, 0);
    const remainingCount = quota.isUnlimited
      ? -1
      : Math.max(quota.totalCount - usedCount, 0);

    transaction.set(
      userReference,
      {
        plan: quota.plan,
        processingLimitTotalCount: quota.totalCount,
        processingLimitUsedCount: usedCount,
        processingLimitRemainingCount: remainingCount,
        processingLimitIsUnlimited: quota.isUnlimited,
        recordingLimitSec: recordingLimitSecondsForPlan(quota.plan),
        audioImportLimitSec: audioImportLimitSecondsForPlan(quota.plan),
        pdfPageLimit: pdfPageLimitForPlan(quota.plan),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true },
    );

    transaction.set(
      documentReference,
      {
        processingQuotaState: "released" as ProcessingQuotaState,
        processingQuotaReleasedAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true },
    );
  });
}
