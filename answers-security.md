# Answers storage & verification approaches

This repository demonstrates two approaches for verifying that a user passed a quiz and is eligible to claim a reward.

Option A — On-chain answers hash (simple demo)
- Admin computes a salted canonical representation of correct answers, e.g. "Q1:A|Q2:B|salt:0xabc".
- Admin calls setAnswersHash(keccak256(bytes(...))) to store the bytes32 on-chain.
- Frontend computes the same hash from user's answers and sends claimWithAnswersHash(hash).
- Contract compares provided hash against stored answersHash and pays out.

Pros:
- Simple to implement.
- No off-chain signing required.

Cons:
- The hash is stored on-chain and can be inspected by anyone. If answers are guessable or unsalted, they can be brute-forced.
- Reveals deterministic information; use a strong salt, but salts may also be brute-forced for small answer spaces.

Option B — Admin-signed off-chain verification (recommended)
- Admin verifies the user's answers off-chain (e.g. by computing answers and scoring) and only signs an approval message tying the claim to the user's address and the campaign address.
- Frontend collects that signature and calls claimWithSignature(signature). Contract recovers the signer and compares to admin.
- Because the admin does verification off-chain, correct answers need not be stored on-chain, preventing leakage.

Pros:
- Keeps answers secret.
- Avoids on-chain exposure and brute-force risk.
- Flexible: admin can add metadata, expiration, partial rewards, and nonces in signed payloads.

Cons:
- Requires an off-chain signer (admin) and a way to distribute signatures.
- Admin must run a secure process to verify and sign claims.

General recommendations for production:
- Use Option B. Include timestamps and nonces in the admin-signed payload to prevent signature replay across campaigns or time windows.
- Use per-user nonces or include claimant address and campaign address in the signed message (this demo includes claimant + campaign binding).
- Use standardized signature formats and EIP-712 if you need structured & extensible signed messages.
- Ensure prize pools are sized or rate-limited to prevent draining via many small claims. Consider allowing admin to set claim limits, or require claim requests to be queued & reviewed.