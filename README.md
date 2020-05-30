# Blind Poll - Anonymous Poll Hosting

Smart contract written in [Clarity](https://docs.blockstack.org/core/smart/clarityref) for [BlockStack](https://docs.blockstack.org).

## Introduction

The Blind Poll smart contract enables users to host anonymous polls, where all submitted answers will be sealed until they're revealed by participants after the poll is closed.

Meanwhile, the contract comes with a fungible token named as BPT (Blind Poll Token) that serves as incentives for users to participate in the poll. Poll creators could choose to put aside some amount of BPT token as rewards for each valid participation, which will get distributed once participants reveal their answers.

## Use Cases

Anonymous poll hosting could be considered as a desired scenario for blockchain, since nowadays the credibility of most polls are guaranteed by trusted third prty, from administrative staff to authoritive agencies, which could lead to poetential manipulation and naturally give rise of doubts for drawn results.

On the other hand, since all data recorded on blockchain are public and transparent, some poll hosts may not expect submitted answers to be witnessed by other participants before the poll closes. Thus, the contract achieve anonymity with seal-and-reveal pattern. To incentivize participants to reveal their answers in time, the contract also binds the actions or answer reveal and reward claim in a single transaction.

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

## Contract Design

The Poll structure defined in the contract includes the following fields:

- subject(buff 128): the text to illustrate the topic of the poll
- ~~start-time(unit): default to the time when the block got mined~~ (preserved)
- ~~duration(unit): in seconds, the span of time a poll should last for~~ (preserved)
- ~~claim-duration(unit): in seconds, the period when participants could reveal answers and claim rewards~~ (preserved)
- rewards(uint): the amount of BPT as rewards for each participant
- max-count(uint): the maximum of acceptable answers in total
- questions(buff 5120): raw bytes of encoded question

How to encode/decode **questions** field of a poll and associated **answers** is totally up to dApp developers utilizing the contract, the contract simply store those fields as raw bytes. Besides, **start-time** and **duration** fields are initially designed to conduct automatic check for the poll lifecycle, but are not used for now since **get-block-info** API does not work as expected, about which I've post [an issue on clarity-js-sdk repo](https://github.com/blockstack/clarity-js-sdk/issues/78).

Besides, the total of rewards is approved by the poll creator as allowance of this contract when creating a new poll. So creators should always assure their accounts have sufficient BPT balance during the whole poll lifecycle. On the other hand, if the balance of the creator's principal is not sufficient to pay off rewards when participants reveal their answers, the creator won't be able to receive those answers, since the actions of reveal and claim are bound to a single transaction.

The overall workflow of poll hosting is demonstrated in the following sequential diagram.

<img width="70%" src="http://qay561y0o.bkt.clouddn.com/sd.svg" />

## Error Codes

| Code  | Thrown When                                                                                                           |
| ----- | --------------------------------------------------------------------------------------------------------------------- |
| -1001 | a principal tries to create a new poll before the previous one closes                                                 |
| -1002 | a principal tries to submit more than one answers for the same poll, or received submissions have reached the maximum |
| -1003 | a principal tries to reveal answers sealed by other users or with incorrect hash                                      |
| -1004 | a principal tries to reveal and claim for the same poll more than once                                                |

## Limitations

- One principal could only host one active poll at the same time, considering limited supports for List in Clarity right now.
- DApp developers should define its own encoding/decoding methods for **questions** and associated **answers,** while the contract just store these two fields as raw bytes.

## Contract APIs

### create-poll-with-guard

Allow legimate users to create and host a new poll with optional rewards in BPT token.

```lisp
(subject (buff 128)) ;; the text to illustrate the topic of the poll
(rewards uint) ;; the amount of BPT as rewards for each participant
(max-count uint) ;; the maximum of acceptable answers in total
(questions (buff 5120)) ;; raw bytes of encoded question in user-defined format
```

### close-poll

Allow poll creators to close the specified poll.

```lisp
(pid uint) ;; ID of the poll intended to be closed
```

### submit-answer-sealed

Allow poll participants to seal and sumit answers for a poll.

```lisp
(pid uint) ;; ID of the target poll
(answer-sealed (buff 32)) ;; keccak-256 hashed answer
```

### reveal-answer

Allow poll participants to reveal answer sealed previously, and claim preset rewards.

```lisp
(pid uint) ;; ID of the target poll
(sealed (buff 32)) ;; sealed answer submitted previously
(answer (buff 512)) ;; original answer that matches the sealed one
```

### query-answer-count-sealed

Allow poll creators to query the total of sealed answers.

```lisp
(pid uint) ;; ID of the target poll
```

### query-answer-count-revealed

Allow poll creators to query the total of revealed answers.

```lisp
(pid uint) ;; ID of the target poll
```

### query-answer-by-index

Allow poll creators to collect revealed answers.

```lisp
(pid uint) ;; ID of the target poll
(i uint) ;; index of answer, upper-bounded by the total of revealed answers
```

## Tests

There're two unit test suites included in the test script, one for normal poll hosting workflow, the other for exceptional cases.

<img width="70%" src="http://qay561y0o.bkt.clouddn.com/test-result.png" />

## Examples

Comprehensive tests with encapsulated clients have been included in the test script, to which you could refer.
