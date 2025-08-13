# 🎟️ Prepaid Service Voucher Smart Contract

## 📌 What

This smart contract lets customers **buy service vouchers on-chain** (💳) for offerings like **spa treatments, gym sessions, cooking classes, or personal training**.

When a voucher is purchased:

1. 💳 Buyer pays the **exact price** into the smart contract.  
2. 🎫 Voucher is **recorded on-chain** with a **validity period** ⏳.  
3. ✅ Service provider redeems the voucher only **after delivering the service**.   
4. 💸 Payment is released to the provider upon redemption.
5. 🔁 If the voucher expires without redemption, the **buyer can self-refund**.  

---

## 🎯 Why

### 🔒 Fraud Prevention 

- ❌ No early provider withdrawals before service is delivered.
- ✅ Funds locked in escrow until **redemption**.

### 📜 Transparent Terms

- ⏳ Expiry date is **immutable** once purchased.
- 💰 Price is **on-chain**, preventing hidden charges.

### ⚖️ Fair for Both Sides

- 🏢 Provider: **Guaranteed payment** when they fulfill the service.
- 👤 Buyer: **Refund protection** if service is not delivered before expiry.

---

## ✨ Symbol Flow

💳 **Pay-in** → 🎫 **Voucher Issued** → ⏳ **Wait / Use Service** → ✅ **Redeem** → 💸 **Provider Withdraws**  
If expired: 🔁 **Buyer Refunds**

---

## 🛠 Key Features

- 📦 **Create offerings**: Providers define price, validity, and service details.
- ⏳ **Expiry system**: No redemption possible after the expiry timestamp.
- 🔁 **Refund options**:
  - Buyer refund after expiry.
  - Provider refund if they cancel service.
- 📜 **Event logging**: Every step (create, buy, redeem, refund, withdraw) is recorded on-chain.
- 🔒 **Reentrancy protection** for safe fund transfers.

---

## 🧩 Roles & Flow

**Provider** 🏢

1. Create offering (`createOffering`)
2. Buyer purchases voucher (`buyVoucher`)
3. Deliver service, redeem voucher (`redeem`)
4. Withdraw funds (`providerWithdraw`)

**Buyer** 👤

1. Choose offering and pay exact price (`buyVoucher`) 💳
2. Use service before expiry ⏳
3. If expired without redemption → get refund (`refundExpired`) 🔁

---

## 📚 Benefits Recap

- 💡 No middleman: Direct escrow between buyer & provider.
- 🔎 Transparent pricing & expiry terms.
- 🛡 Protects against both **prepayment scams** and **non-payment disputes**.
- 🧾 Clear on-chain history of transactions for accountability.

---
