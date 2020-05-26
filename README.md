# Blind Poll

Smart contracts written in [Clarity](https://docs.blockstack.org/core/smart/clarityref) for [BlockStack]((https://docs.blockstack.org)).

## Introduction

The Blind Poll smart contract enables users to host anonymous polls with possible token incentive.

The fungible token that comes with the contract is named as BPT (Blind Poll Token). To incentivize users to participate in the poll, the initiator could choose to put aside some amount of BPT token as rewards for each valid participation, which will get distributed after the poll concludes.

The total of rewards is approved by the poll creator as allowance of this contract when creating a new poll. Therefore, if the balance of the creator principal is not sufficient when participants claim rewards, the creator won't be able to receive revealed answers, since the actions of reveal and claim are bound to a single transaction.

Poll structure defined in the contract includes following fields:

- subject(buff 128): string to illustrate topic of the poll
- ~~start-time(unit): default to the time when the block got mined~~ (preserved)
- ~~duration(unit): in seconds, the period of time the poll should last for~~ (preserved)
- ~~claim-duration(unit): in seconds, the period of time participants could reveal answers and claim rewards~~ (preserved)
- rewards(uint): amount of BPT as rewards for each participant
- max-count(uint): maximum of acceptable answers in total
- questions(buff 5120): raw bytes of encoded question

To be noted, how to encode/decode **questions** field of a poll and associated **answers** field should be decided by dApp developers, the contract simply treat it as raw bytes. Besides, the **startime** and **duration** fields are not used for now, since **get-block-info** API does not work as expected, and as a result, automatic time check is replaced by manual call for poll lifecycle management.

## Features / Use Cases

Functionalities the contracts provide include:

### As a poll creator

- Create a new poll with and optionally distribute reward in BPT to participant
- Query last created poll ID for later interactions
- Close the poll at any time
- Query the total of sealed or revealed answers, and iterate over all revealed answers

### As a poll participant

- Query poll detail by ID
- Join in an ongoing poll and submit a sealed answer for it
- Reveal a answer submitted before and claim rewards after the poll closes

## Sequential Diagram

You could refer to the following diagram to grasp the overall workflow.

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

## Constraints

- One principal could only host one active poll at the same time, considering limited supports for List in Clarity right now.
- DApp developers should define its own encoding/decoding methods for poll **questions** and associated **answers,** while the contract just treat these two fields as raw bytes.

## Error Codes

| Code  | Thrown When                                                                                                           |
| ----- | --------------------------------------------------------------------------------------------------------------------- |
| -1001 | a principal tries to create a new poll before the previous one closes                                                 |
| -1002 | a principal tries to submit more than one answers for the same poll, or received submissions have reached the maximum |
| -1003 | a principal tries to reveal answers sealed by other users or with incorrect hash                                      |
| -1004 | a principal tries to reveal and claim for the same poll more than once                                                |

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

## Examples

Comprehensive tests have been included in the test script, to which you could refer.
