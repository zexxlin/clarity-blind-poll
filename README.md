# Blind Poll - Anonymous Poll Hosting

Smart contract written in [Clarity](https://docs.blockstack.org/core/smart/clarityref) for [BlockStack](<(https://docs.blockstack.org)>).

## Introduction

The Blind Poll smart contract enables users to host anonymous polls, where all submitted answers will be sealed until they're revealed by participants after the poll is closed.

Moreover, the contract comes with a fungible token named as BPT (Blind Poll Token) that serves as incentives for users to participate in the poll. Poll creators could choose to put aside some amount of BPT token as rewards for each valid participation, which will get distributed once participants reveal their answers.

Note that, the total of rewards is approved by the poll creator as allowance of this contract when creating a new poll. So creators should always assure their accounts have sufficient BPT balance during the whole poll lifecycle. On the other hand, if the balance of the creator's principal is not sufficient to pay off rewards when participants reveal their answers, the creator won't be able to receive those answers, since the actions of reveal and claim are bound to a single transaction.

The Poll structure defined in the contract includes the following fields:

- subject(buff 128): string to illustrate the topic of the poll
- ~~start-time(unit): default to the time when the block got mined~~ (preserved)
- ~~duration(unit): in seconds, the span of time a poll should last for~~ (preserved)
- ~~claim-duration(unit): in seconds, the period when participants could reveal answers and claim rewards~~ (preserved)
- rewards(uint): the amount of BPT as rewards for each participant
- max-count(uint): maximum of acceptable answers in total
- questions(buff 5120): raw bytes of encoded question

To be noted, how to encode/decode **questions** field of a poll and associated **answers** is totally up to dApp developers utilizing the contract, the contract simply store those fields as raw bytes. Besides, **start-time** and **duration** fields are initially designed to conduct automatic check for the poll lifecycle, but are not used for now since **get-block-info** API does not work as expected, about which I've post [an issue on clarity-js-sdk repo](https://github.com/blockstack/clarity-js-sdk/issues/78).

## Features / Use Cases

### As a poll creator

- Create a new anonymous poll with optional incentives in BPT token
- Query the last created poll
- Close an active poll
- Query the total number of sealed and revealed answers
- Collect all revealed answers to conduct further off-chain analysis

### As a poll participant

- Query poll detail by ID
- Join in an ongoing poll and submit a sealed answer for it
- Reveal a sealed answer and claim rewards for it

## Sequential Diagram

The overall workflow of poll hosting is demonstrated in the following diagram.

```mermaid
sequenceDiagram
    participant A as Poll Owner
    participant B as Blind-Poll Contract
    participant C as BPT-Token Contract
    participant D as Participant


    A ->> B: Craete a poll
    A ->> C: Approve allowance for poll contract
    A ->> D: Share returned poll ID
    D ->> B: Query poll detail
    B -->> D: Poll detail
    D ->> B: Submit sealed answer
    A ->> B: Query total of received answers
    A ->> B: Close the poll
    D ->> B: Reveal answer and claim rewards
    B ->> C: Transfer from creator's allowance
    C -->> D: Received BPT tokens
    A ->> B: Collect answers
    A ->> A: Conduct off-chain statistics
```

## Error Codes

| Code  | Thrown When                                                                                                           |
| ----- | --------------------------------------------------------------------------------------------------------------------- |
| -1001 | a principal tries to create a new poll before the previous one closes                                                 |
| -1002 | a principal tries to submit more than one answers for the same poll, or received submissions have reached the maximum |
| -1003 | a principal tries to reveal answers sealed by other users or with incorrect hash                                      |
| -1004 | a principal tries to reveal and claim for the same poll more than once                                                |

## Constraints

- One principal could only host one active poll at the same time, considering limited supports for List in Clarity right now.
- DApp developers should define its own encoding/decoding methods for **questions** and associated **answers,** while the contract just store these two fields as raw bytes.

## APIs

### create-poll-with-guard

```
(subject (buff 128))
(rewards uint)
(max-count uint)
(questions (buff 5120))
```

### close-poll

```
(pid uint)
```

### submit-answer-sealed

```
(pid uint)
(answer-sealed (buff 32))
```

### reveal-answer

```
(pid uint)
(sealed (buff 32))
(answer (buff 512))
```

### query-answer-count-sealed

```
(pid uint)
```

### query-answer-count-revealed

```
(pid uint)
```

### query-answer-by-index

```
(pid uint)
(i uint)
```

## Tests

There're two test suites included in the test script, one for normal poll hosting workflow, the other for exceptional cases.

<img width="60%" src="http://qay561y0o.bkt.clouddn.com/test-result.png" />

## Examples

Comprehensive tests have been included in the test script, to which you could refer.
