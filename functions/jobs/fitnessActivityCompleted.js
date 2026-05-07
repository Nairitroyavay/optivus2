// functions/jobs/fitnessActivityCompleted.js
//
// Firestore onWrite trigger: /users/{uid}/fitnessActivities/{activityId}
// Runs when an activity is completed. Updates stats and checks goals.
// Idempotent via `statsProcessedAt` marker on the activity doc.

const admin = require("firebase-admin");
const { onDocumentWritten } = require("firebase-functions/v2/firestore");

const db = admin.firestore();

/**
 * ISO 8601 week number.
 */
function isoWeekNumber(date) {
  const d = new Date(Date.UTC(date.getFullYear(), date.getMonth(), date.getDate()));
  d.setUTCDate(d.getUTCDate() + 4 - (d.getUTCDay() || 7));
  const yearStart = new Date(Date.UTC(d.getUTCFullYear(), 0, 1));
  return Math.ceil(((d - yearStart) / 86400000 + 1) / 7);
}

/**
 * Generate period keys for a given date.
 */
function periodKeys(date) {
  const y = date.getFullYear().toString().padStart(4, "0");
  const m = (date.getMonth() + 1).toString().padStart(2, "0");
  const d = date.getDate().toString().padStart(2, "0");
  const w = isoWeekNumber(date).toString().padStart(2, "0");

  return {
    daily: `daily_${y}-${m}-${d}`,
    weekly: `weekly_${y}-W${w}`,
    monthly: `monthly_${y}-${m}`,
  };
}

exports.onFitnessActivityCompleted = onDocumentWritten(
  "users/{uid}/fitnessActivities/{activityId}",
  async (event) => {
    const beforeData = event.data?.before?.data();
    const afterData = event.data?.after?.data();

    if (!afterData) return; // Deletion — nothing to do.

    // Only trigger on completion transitions.
    const wasCompleted = beforeData?.status === "completed";
    const isCompleted = afterData.status === "completed";
    if (!isCompleted || wasCompleted) return;

    // Idempotency check: skip if already processed.
    if (afterData.statsProcessedAt) {
      console.log(`[fitnessActivityCompleted] Already processed ${event.params.activityId}`);
      return;
    }

    const uid = event.params.uid;
    const activityId = event.params.activityId;
    const completedAt = afterData.completedAt?.toDate?.() || afterData.endedAt?.toDate?.() || new Date();
    const keys = periodKeys(completedAt);
    const activityType = afterData.type || afterData.activityType || "custom";
    const distanceMeters = afterData.distanceMeters || 0;
    const durationMs = (afterData.durationSeconds || 0) * 1000;
    const calories = afterData.calories || afterData.caloriesEstimate || 0;

    const batch = db.batch();
    const userRef = db.collection("users").doc(uid);

    // ── Update stats for each period ────────────────────────────────────
    for (const [periodType, key] of [
      ["daily", keys.daily],
      ["weekly", keys.weekly],
      ["monthly", keys.monthly],
    ]) {
      const statsRef = userRef.collection("fitnessStats").doc(key);
      batch.set(
        statsRef,
        {
          periodKey: key,
          periodType,
          totalActivities: admin.firestore.FieldValue.increment(1),
          totalDistanceMeters: admin.firestore.FieldValue.increment(distanceMeters),
          totalDurationMs: admin.firestore.FieldValue.increment(durationMs),
          totalCalories: admin.firestore.FieldValue.increment(calories),
          [`activityBreakdown.${activityType}`]: admin.firestore.FieldValue.increment(1),
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
        },
        { merge: true }
      );
    }

    // ── Mark activity as processed ──────────────────────────────────────
    const activityRef = userRef.collection("fitnessActivities").doc(activityId);
    batch.update(activityRef, {
      statsProcessedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    await batch.commit();
    console.log(`[fitnessActivityCompleted] Stats updated for ${activityId} — keys: ${Object.values(keys).join(", ")}`);

    // ── Check and update goals ──────────────────────────────────────────
    try {
      const goalsSnap = await userRef
        .collection("fitnessGoals")
        .where("status", "==", "active")
        .get();

      if (goalsSnap.empty) return;

      const goalBatch = db.batch();
      let goalsUpdated = 0;

      for (const goalDoc of goalsSnap.docs) {
        const goal = goalDoc.data();
        let increment = 0;

        switch (goal.goalType) {
          case "weekly_distance":
          case "monthly_distance":
            increment = distanceMeters / 1000; // Convert to km
            break;
          case "weekly_activities":
            increment = 1;
            break;
          case "weekly_duration":
            increment = durationMs / 60000; // Convert to minutes
            break;
          default:
            continue;
        }

        if (increment > 0) {
          goalBatch.update(goalDoc.ref, {
            currentValue: admin.firestore.FieldValue.increment(increment),
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          });
          goalsUpdated++;
        }
      }

      if (goalsUpdated > 0) {
        await goalBatch.commit();
        console.log(`[fitnessActivityCompleted] Updated ${goalsUpdated} goals`);
      }
    } catch (err) {
      console.error(`[fitnessActivityCompleted] Goal update failed:`, err);
    }
  }
);
