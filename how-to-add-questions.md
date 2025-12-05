# How to add Quiz Questions (IPFS vs On-chain)

You have two main options to provide quiz metadata:

1) Off-chain JSON (recommended)
- Host your questions JSON at a static URL or IPFS CID.
- The JSON should contain:
  - title, description
  - questions: array of { id, question, options: [] }
  - optional answersExampleFormat field to help demo users
- Example: examples/questions/sample-questions.json
- When creating a campaign, include the metadata URL (IPFS CID or HTTPS) as metadataURI.

2) On-chain (not recommended for full text)
- You could store small strings on-chain, but it's expensive and not needed.
- Store only a pointer (IPFS CID) on-chain using metadataURI.

Security note:
- If you use Option A (answersHash on-chain), never publish the correct answers in the same metadata JSON. Instead, produce a hashed/salted representation and only set the hash using the admin interface.