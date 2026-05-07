// functions/jobs/fitnessGoalUpdated.js
//
// Firestore onWrite trigger: /users/{uid}/fitnessGoals/{goalId}
// When currentValue >= targetValue and status == 'active', marks completed.
// Idempotent via status check.

const admin = require("firebase-admin");
const { onDocumentWritten } = require("firebase-functions/v2/firestore");

const db = admin.firestore();

exports.onFitnessGoalUpdated = onDocumentWritten(
  "users/{uid}/fitnessGoals/{goalId}",
  async (event) => {
    const afterData = event.data?.after?.data();
    if (!afterData) return; // Deletion — nothing to do.

    // Only process active goals.
    if (afterData.status !== "active") return;

    const currentValue = afterData.currentValue || 0;
    const targetValue = afterData.targetValue || 0;

    // Check if goal is completed.
    if (targetValue <= 0 || currentValue < targetValue) return;

    const uid = event.params.uid;
    const goalId = event.params.goalId;
    const goalRef = db
      .collection("users")
      .doc(uid)
      .collection("fitnessGoals")
      .doc(goalId);

    // Mark goal as completed.
    await goalRef.update({
      status: "completed",
      completedAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    // Write a celebration event.
    try {
      const eventRef = db
        .collection("users")
        .doc(uid)
        .collection("events")
        .doc();

      await eventRef.set({
        eventId: eventRef.id,
        eventName: afterData.goalType === "weekly_distance"
          ? "weekly_distance_goal_completed"
          : "fitness_goal_completed",
        payload: {
          goalId,
          goalType: afterData.goalType || "unknown",
          targetValue,
          currentValue,
          unit: afterData.unit || "unknown",
        },
        source: "cloud_function",
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      console.log(`[fitnessGoalUpdated] Goal ${goalId} completed for user ${uid}`);
    } catch (err) {
      console.error(`[fitnessGoalUpdated] Event write failed:`, err);
    }
  }
);
