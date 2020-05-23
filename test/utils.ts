const REG_EXTRACT_KV = /\([\w|-]+ \w+\)/g;
const REG_RESP = /Returned: (.*)\n/;
const REG_ERROR = /Aborted: (.*)$/;

function unwrapPlainTuple(raw: string) {
  return raw.match(REG_EXTRACT_KV).reduce((prev, s) => {
    const [key, val] = s.slice(1, s.length - 1).split(" ");
    return {
      ...prev,
      [key.replace(/-([a-z])/, (_, d) => d.toUpperCase())]: val,
    };
  }, {});
}

function extractResp(raw: string) {
  if (!raw) {
    return null;
  }
  const m = raw.match(REG_RESP);
  return m && m[1];
}

function extractErrorCode(raw: string) {
  if (!raw) {
    return null;
  }
  const m = raw.match(REG_ERROR);
  return m && m[1];
}

async function query(client, { method, args = [] }) {
  const query = client.createQuery({
    method: { name: method, args },
  });
  const receipt = await client.submitQuery(query);
  if (receipt.success) {
    return receipt;
  } else {
    return null;
  }
}

const submitTx = async (client, { method, args = [], sender }) => {
  const tx = client.createTransaction({
    method: {
      name: method,
      args,
    },
  });
  await tx.sign(sender);
  const receipt = await client.submitTransaction(tx);
  if (receipt.success) {
    return extractResp(receipt.result);
  } else {
    // console.log(receipt);
    const errCode = extractErrorCode(receipt.error.commandOutput);
    throw new Error(errCode || receipt.error);
  }
};

export { unwrapPlainTuple, query, submitTx };
