import { Client, Provider } from "@blockstack/clarity";
import { query, submitTx } from "./utils";

class TokenClient extends Client {
  submitTx: any;
  query: any;
  constructor(name: string, filePath: string, provider: Provider) {
    super(name, filePath, provider);
    this.submitTx = submitTx.bind(this, this);
    this.query = query.bind(this, this);
  }

  async balanceOf(owner) {
    return await this.query({
      method: "balance-of",
      args: [`'${owner}`],
    });
  }

  async allowanceOf(owner, spender) {
    return await this.query({
      method: "allowance-of",
      args: [`'${owner}`, `'${spender}`],
    });
  }

  async mint(sender, recipient, amount) {
    return await this.submitTx({
      method: "mint",
      args: [`u${amount}`, `'${recipient}`],
      sender,
    });
  }

  async transferFrom(spender, owner, recipient, amount) {
    return await this.submitTx({
      method: "transfer-from",
      args: [`'${owner}`, `'${recipient}`, `u${amount}`],
      sender: spender,
    });
  }
}

export default TokenClient;
