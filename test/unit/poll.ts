import { Provider, ProviderRegistry } from "@blockstack/clarity";
import { assert } from "chai";
import PollClient from "./pollClient";
import TokenClient from "./tokenClient";

const POLL_CONTRACT_ADDR =
  "SP3GWX3NE58KXHESRYE4DYQ1S31PQJTCRXB3PE9SB.blind-poll";
const TOKEN_CONTRACT_ADDR = "SP3GWX3NE58KXHESRYE4DYQ1S31PQJTCRXB3PE9SB.token";
const addrs = [
  "ST37X0038BZV6YV0MQCJ0G6QMZZ75QS64KA69V9D",
  "SZ2J6ZY48GV1EZ5V2V5RB9MP66SW86PYKKQ9H6DPR",
  "SP3GWX3NE58KXHESRYE4DYQ1S31PQJTCRXB3PE9SB",
  "ST1BG7MHW2R524WMF7X8PGG3V45ZN040EB9EW0GQJ",
];

describe("test suite for poll lifecycle", () => {
  let provider: Provider;
  let pollClient: PollClient;
  let tokenClient: TokenClient;
  let lastPID;
  const initBal = 100;

  // poll example
  const questions = [
    {
      text: "Favorite dApp genre?",
      options: ["Gaming", "Forecast", "Financial Service"],
    },
  ];
  const newPoll = {
    subject: "Your Favorite dApp",
    // duration: "u86400",
    // claimDuration: "u43200",
    rewards: "u1",
    maxCount: "u100",
    questions,
  };
  const answers = [
    [0, 1, 2],
    [2, 1, 0],
  ];

  before(async () => {
    provider = await ProviderRegistry.createProvider();
    tokenClient = new TokenClient(TOKEN_CONTRACT_ADDR, "token", provider);
    pollClient = new PollClient(POLL_CONTRACT_ADDR, "blind-poll", provider);
    await tokenClient.checkContract();
    await tokenClient.deployContract();
    // await pollClient.checkContract();
    await pollClient.deployContract();
  });

  describe("as a poll creator", () => {
    it("should get BPT tokens before creating a poll", async () => {
      await tokenClient.mint(addrs[0], addrs[0], initBal);
      let bal = await tokenClient.balanceOf(addrs[0]);
      assert.equal(bal, `u${initBal}`, "incorrect BPT balance");

      bal = await tokenClient.balanceOf(addrs[1]);
      assert.equal(bal, "u0");

      bal = await tokenClient.balanceOf(addrs[2]);
      assert.equal(bal, "u0");
    });

    it("should create a new poll and approve specified amount of token as allowance of the poll contract", async () => {
      lastPID = await pollClient.createPoll(addrs[0], newPoll);
      assert.equal(lastPID, "u1");

      // check if specified amount of allowance has been approved
      const allowance = await tokenClient.allowanceOf(
        addrs[0],
        POLL_CONTRACT_ADDR
      );
      assert.equal(allowance, `u${initBal}`);
    });

    it("should return the id of last poll created by current tx sender", async () => {
      const pid = await pollClient.queryLastPollID(addrs[0]);
      assert.equal(pid, lastPID);
    });

    it("should intialize the answer counter for the poll ", async () => {
      const sealedCount = await pollClient.queryCountOfSealedAnswers(
        addrs[0],
        lastPID
      );
      const revealedCount = await pollClient.queryCountOfRevealedAnswers(
        addrs[0],
        lastPID
      );
      assert.equal(sealedCount, "u0");
      assert.equal(revealedCount, "u0");
    });
  });

  describe("as a poll participant", () => {
    it("should return detail of a poll", async () => {
      let detail = await pollClient.queryPollByID(lastPID);
      newPoll["pollId"] = lastPID;
      assert.deepEqual(detail, newPoll);
    });
    it("should submit sealed answer for a poll", async () => {
      for (let i = 0; i < answers.length; i++) {
        let res = await pollClient.submitSealedAnswer(
          addrs[i + 1],
          lastPID,
          answers[i]
        );
        assert.equal(res, "1");
      }
    });
  });

  describe("when poll creator decided to close the poll", () => {
    it("poll creator should return the total of sealed answers ", async () => {
      const sealedCount = await pollClient.queryCountOfSealedAnswers(
        addrs[0],
        lastPID
      );
      assert.equal(sealedCount, "u2");
    });

    it("poll creator should close the poll", async () => {
      const res = await pollClient.closePoll(addrs[0], lastPID);
      assert.equal(res, "true");
    });

    it("poll participant should reveal answer and receive rewards", async () => {
      for (let i = 0; i < answers.length; i++) {
        const res = await pollClient.revealAnswer(
          addrs[i + 1],
          lastPID,
          answers[i]
        );
        assert.equal(res, "1");
        // check received rewards
        const bal = await tokenClient.balanceOf(addrs[i + 1]);
        assert.equal(bal, newPoll.rewards, "incorrect rewards received");
      }
      const bal = await tokenClient.balanceOf(addrs[0]);
      assert.equal(
        bal,
        `u${initBal - answers.length * parseInt(newPoll.rewards.slice(1))}`,
        "incorrect balance after distribution"
      );

      const allowance = await tokenClient.allowanceOf(
        addrs[0],
        POLL_CONTRACT_ADDR
      );
      assert.equal(
        allowance,
        `u${initBal - answers.length * parseInt(newPoll.rewards.slice(1))}`,
        "incorrect allowance after distribution"
      );
    });

    it("poll creator should return the total of revealed answers ", async () => {
      const revealedCount = await pollClient.queryCountOfRevealedAnswers(
        addrs[0],
        lastPID
      );
      assert.equal(revealedCount, "u2");
    });

    it("poll creator should iterate and collect all revealed answers", async () => {
      const revealedCount = await pollClient.queryCountOfRevealedAnswers(
        addrs[0],
        lastPID
      );
      for (let i = 0; i < parseInt(revealedCount.slice(1)); i++) {
        const curr = await pollClient.queryAnswerByIndex(addrs[0], lastPID, i);
        assert.deepEqual(curr, answers[i]);
      }
    });
  });

  after(async () => {
    await provider.close();
  });
});

describe("test suite for exception handling", () => {
  let lastPID;
  let pollClient: PollClient;
  let tokenClient: TokenClient;
  let provider: Provider;

  // poll example
  const questions = [
    {
      text: "Favorite dApp genre?",
      options: ["Gaming", "Forecast", "Financial Service"],
    },
  ];
  const newPoll = {
    subject: "Your Favorite dApp",
    // duration: "u86400",
    // claimDuration: "u43200",
    rewards: "u0",
    maxCount: "u1",
    questions,
  };
  const answers = [
    [0, 1, 2],
    [2, 1, 0],
  ];

  before(async () => {
    provider = await ProviderRegistry.createProvider();
    pollClient = new PollClient(POLL_CONTRACT_ADDR, "blind-poll", provider);
    tokenClient = new TokenClient(TOKEN_CONTRACT_ADDR, "token", provider);
    await tokenClient.checkContract();
    await tokenClient.deployContract();
    // await client.checkContract();
    await pollClient.deployContract();

    lastPID = await pollClient.createPoll(addrs[0], newPoll);
    assert.equal(lastPID, "u1");
  });

  it("shouldn't create a new poll before the old one closes", async () => {
    let err1;
    try {
      await pollClient.createPoll(addrs[0], newPoll);
    } catch (err) {
      err1 = err;
    }
    assert.equal(err1.message, "-1001");

    const res = await pollClient.closePoll(addrs[0], lastPID);
    assert.equal(res, "true");

    lastPID = await pollClient.createPoll(addrs[0], newPoll);
    assert.equal(lastPID, "u2");
  });

  it("shouldn'submit answers repeatly under the same principal", async () => {
    const res = await pollClient.submitSealedAnswer(
      addrs[1],
      lastPID,
      answers[0]
    );
    assert.equal(res, "1");

    let err1;
    try {
      await pollClient.submitSealedAnswer(addrs[1], lastPID, answers[0]);
    } catch (err) {
      err1 = err;
    }
    assert.equal(err1.message, "-1002");
  });

  it("shouldn't exceed the maximum accepatable amount of answers", async () => {
    let err1;
    // try to submit a second answer with max-count set to 1
    try {
      await pollClient.submitSealedAnswer(addrs[2], lastPID, answers[0]);
    } catch (err) {
      err1 = err;
    }
    assert.equal(err1.message, "-1002");
  });

  it("shouldn't reveal answer before the poll closes", async () => {
    let err1;
    try {
      await pollClient.revealAnswer(addrs[1], lastPID, answers[0]);
    } catch (err) {
      err1 = err;
    }
    assert.isTrue(!!err1);
  });

  it("shouldn't reveal answers sealed by other users or with incorrect hash", async () => {
    const res = await pollClient.closePoll(addrs[0], lastPID);
    assert.equal(res, "true");

    let err1, err2;
    try {
      await pollClient.revealAnswer(addrs[2], lastPID, answers[0]);
    } catch (err) {
      err1 = err;
    }
    try {
      await pollClient.revealAnswer(
        addrs[1],
        lastPID,
        answers[0],
        "0x1234abcd"
      );
    } catch (err) {
      err2 = err;
    }
    assert.isTrue(!!err1, "shouldn't have revealed other's answer");
    assert.equal(
      err2.message,
      "-1003",
      "shouldn't have reveal with incorrect hash"
    );
  });

  it("should return 0 when a principal who hasn't created a poll tries to query last pid", async () => {
    const lastPID = await pollClient.queryLastPollID(addrs[1]);
    assert.equal(lastPID, "u0");
  });
});
