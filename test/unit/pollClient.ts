import { Client, Provider } from "@blockstack/clarity";
import { unwrapPlainTuple, query, submitTx } from "./utils";
import { Keccak } from "sha3";

function encode(s) {
  if (typeof s == "object") {
    return "0x" + Buffer.from(JSON.stringify(s)).toString("hex");
  }
  return "0x" + Buffer.from(s).toString("hex");
}

function decode(o) {
  if (typeof o == "string" && o.startsWith("0x")) {
    o = Buffer.from(o.slice(2), "hex").toString();
    try {
      o = JSON.parse(o);
    } catch (e) {}
  }
  if (typeof o == "object") {
    for (const key in o) {
      o[key] = decode(o[key]);
    }
    return o;
  }
  return o;
}

function keccak256(s: string) {
  const hash = new Keccak(256);
  hash.update(Buffer.from(s.slice(2), "hex"));
  return "0x" + hash.digest("hex");
}

class PollClient extends Client {
  submitTx: any;
  query: any;
  constructor(name: string, filePath: string, provider: Provider) {
    super(name, filePath, provider);
    this.submitTx = submitTx.bind(this, this);
    this.query = query.bind(this, this);
  }

  async createPoll(sender: string, { subject, rewards, maxCount, questions }) {
    return this.submitTx({
      method: "create-poll-with-guard",
      args: [encode(subject), rewards, maxCount, encode(questions)],
      sender,
    });
  }

  async queryLastPollID(sender) {
    return await this.query({
      method: "query-last-poll-id",
      args: [`'${sender}`],
    });
  }

  async queryPollByID(pid) {
    let detail = await this.query({
      method: "query-poll-by-id",
      args: [pid],
    });
    if (detail) {
      detail = decode(unwrapPlainTuple(detail));
    }
    return detail;
  }

  async submitSealedAnswer(sender, pid, answer) {
    return await this.submitTx({
      method: "submit-answer-sealed",
      sender,
      args: [pid, keccak256(encode(answer))],
    });
  }

  async revealAnswer(sender, pid, answer, sealed?) {
    return await this.submitTx({
      method: "reveal-answer",
      sender,
      args: [pid, sealed || keccak256(encode(answer)), encode(answer)],
    });
  }

  async closePoll(sender, pid) {
    return await this.submitTx({
      method: "close-poll",
      sender,
      args: [pid],
    });
  }

  async queryCountOfSealedAnswers(sender, pid) {
    return await this.submitTx({
      method: "query-answer-count-sealed",
      args: [pid],
      sender,
    });
  }

  async queryCountOfRevealedAnswers(sender, pid) {
    return await this.submitTx({
      method: "query-answer-count-revealed",
      args: [pid],
      sender,
    });
  }

  async queryAnswerByIndex(sender, pid, i) {
    const res = await this.submitTx({
      method: "query-answer-by-index",
      sender,
      args: [pid, `u${i}`],
    });
    return res && decode(res);
  }
}

export default PollClient;
