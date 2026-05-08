"use strict";

const assert = require("assert");
const { _private } = require("../ai/coachReply");

function baseRequest(overrides = {}) {
  return {
    auth: { uid: "user_1" },
    data: {
      userId: "user_1",
      threadId: "main_thread",
      text: "I need help getting back on track today.",
      mode: "chat",
      ...overrides,
    },
  };
}

function makeTestHandler(overrides = {}) {
  const writes = [];
  let generateCalls = 0;
  let ids = 0;

  const handler = _private.makeCoachReplyHandler({
    db: {},
    now: () => new Date("2026-05-08T00:00:00.000Z"),
    toTimestamp: (date) => ({ iso: date.toISOString() }),
    makeId: (prefix) => `${prefix}_${++ids}`,
    loadLatestContextSnapshot: async () => ({
      id: "snapshot_1",
      data: {
        goals: ["Build a consistent morning routine"],
        userState: "on_track",
        missionScore: 72,
        tasksCompletedToday: 1,
        badHabitSlipsToday: 0,
      },
    }),
    loadRecentMessages: async () => [
      { role: "user", text: "I have a lot to do." },
      { role: "coach", text: "Pick the next small action." },
    ],
    generateReplyJson: async () => {
      generateCalls += 1;
      return JSON.stringify({
        text: "Pick one 10-minute task and start there. Keep it simple enough that momentum is the win.",
        suggestedActions: ["Start a 10-minute task", "Review today's plan"],
      });
    },
    writeReplyAndEvent: async (write) => {
      writes.push(write);
    },
    ...overrides,
  });

  return {
    handler,
    writes,
    get generateCalls() {
      return generateCalls;
    },
  };
}

describe("coachReply — callable contract", () => {
  it("returns a validated reply and writes the trusted coach message plus coach_replied event", async () => {
    const harness = makeTestHandler();

    const result = await harness.handler(baseRequest());

    assert.strictEqual(result.text.includes("10-minute task"), true);
    assert.deepStrictEqual(result.suggestedActions, [
      "Start a 10-minute task",
      "Review today's plan",
    ]);
    assert.strictEqual(result.messageId, "coach_reply_1");
    assert.strictEqual(result.safetyBranch, "normal");
    assert.strictEqual(harness.generateCalls, 1);
    assert.strictEqual(harness.writes.length, 1);

    const write = harness.writes[0];
    assert.strictEqual(write.uid, "user_1");
    assert.strictEqual(write.messageData.text, result.text);
    assert.strictEqual(write.messageData.source, "coachReply");
    assert.strictEqual(write.messageData.contextSnapshotId, "snapshot_1");
    assert.strictEqual(write.logId, "coach_speak_log_3");
    assert.strictEqual(write.speakLogData.decision, "spoke");
    assert.strictEqual(write.speakLogData.ruleId, null);
    assert.strictEqual(write.speakLogData.messagePath, "users/user_1/coach_messages/coach_reply_1");
    assert.strictEqual(write.eventData.eventName, "coach_replied");
    assert.strictEqual(write.eventData.payload.messageId, result.messageId);
    assert.strictEqual(JSON.stringify(result).includes("GEMINI_API_KEY"), false);
  });

  it("routes crisis keywords before the LLM and writes a crisis safety reply", async () => {
    const harness = makeTestHandler({
      generateReplyJson: async () => {
        throw new Error("LLM should not be called for crisis text");
      },
    });

    const result = await harness.handler(baseRequest({
      text: "I want to die and I cannot go on.",
    }));

    assert.strictEqual(result.safetyBranch, "crisis");
    assert.strictEqual(result.text.includes("988"), true);
    assert.strictEqual(harness.generateCalls, 0);
    assert.strictEqual(harness.writes.length, 1);
    assert.strictEqual(harness.writes[0].messageData.aiGenerated, false);
    assert.strictEqual(harness.writes[0].messageData.safetyBranch, "crisis");
    assert.strictEqual(harness.writes[0].speakLogData.safetyBranch, "crisis");
    assert.strictEqual(harness.writes[0].eventData.priority, "high");
  });

  it("rejects model output that does not match the reply schema", async () => {
    const harness = makeTestHandler({
      generateReplyJson: async () => JSON.stringify({
        text: "",
        suggestedActions: "Start",
      }),
    });

    await assert.rejects(
      () => harness.handler(baseRequest()),
      (error) => error.code === "internal"
    );
    assert.strictEqual(harness.writes.length, 0);
  });
});

describe("coachReply — context fallback", () => {
  function makeFallbackDb({ snapshotData = null } = {}) {
    return {
      collection: (collectionName) => {
        assert.strictEqual(collectionName, "users");
        return {
          doc: (uid) => ({
            get: async () => ({
              exists: true,
              data: () => ({
                onboarding: {
                  goals: ["Run a 5K"],
                  coachStyle: "Direct and calm",
                },
                uid,
              }),
            }),
            collection: (subcollectionName) => {
              if (subcollectionName === "goals") {
                return {
                  get: async () => ({
                    docs: [
                      { data: () => ({ title: "Build strength" }) },
                    ],
                  }),
                };
              }

              if (subcollectionName === "ai_context_snapshots") {
                return {
                  orderBy() {
                    return this;
                  },
                  limit() {
                    return this;
                  },
                  get: async () => snapshotData
                    ? {
                        empty: false,
                        docs: [
                          {
                            id: "snapshot_without_goals",
                            data: () => snapshotData,
                          },
                        ],
                      }
                    : { empty: true, docs: [] },
                };
              }

              throw new Error(`Unexpected subcollection ${subcollectionName}`);
            },
          }),
        };
      },
    };
  }

  it("uses onboarding and goal docs when no context snapshot exists", async () => {
    const snapshot = await _private.loadLatestContextSnapshot(makeFallbackDb(), "user_1");

    assert.strictEqual(snapshot.id, null);
    assert.deepStrictEqual(snapshot.data.goals, ["Run a 5K", "Build strength"]);
    assert.strictEqual(snapshot.data.source, "fallback_user_profile");
  });

  it("enriches an existing snapshot that does not contain goals", async () => {
    const snapshot = await _private.loadLatestContextSnapshot(
      makeFallbackDb({ snapshotData: { userState: "recovering", missionScore: 35 } }),
      "user_1"
    );

    assert.strictEqual(snapshot.id, "snapshot_without_goals");
    assert.strictEqual(snapshot.data.userState, "recovering");
    assert.strictEqual(snapshot.data.missionScore, 35);
    assert.deepStrictEqual(snapshot.data.goals, ["Run a 5K", "Build strength"]);
  });
});
