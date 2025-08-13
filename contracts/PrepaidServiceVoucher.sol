// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

contract PrepaidServiceVoucher {
    // ---------- Types ----------
    struct Offering {
        address provider; // Service provider (spa/gym/tutor/etc.)
        uint256 price; // Price in wei
        uint256 validityPeriod; // Seconds from purchase to expiry
        bool active; // Can users buy?
        string metadataURI; // Off-chain details (name, terms)
    }

    struct Voucher {
        uint256 offeringId;
        address buyer;
        uint64 purchaseTime;
        uint64 expiry;
        bool redeemed;
        bool refunded;
    }

    // ---------- Storage ----------
    uint256 public nextOfferingId;
    uint256 public nextVoucherId;

    mapping(uint256 => Offering) public offerings; // offeringId => Offering
    mapping(uint256 => Voucher) public vouchers; // voucherId  => Voucher
    mapping(address => uint256) public providerBalances; // provider => withdrawable

    // simple nonReentrancy
    uint256 private _locked;

    // ---------- Events ----------
    event OfferingCreated(
        uint256 indexed offeringId,
        address indexed provider,
        uint256 price,
        uint256 validityPeriod,
        string metadataURI
    );
    event OfferingUpdated(
        uint256 indexed offeringId,
        uint256 price,
        uint256 validityPeriod,
        bool active,
        string metadataURI
    );
    event VoucherPurchased(
        uint256 indexed voucherId,
        uint256 indexed offeringId,
        address indexed buyer,
        uint256 price,
        uint256 expiry
    );
    event VoucherRedeemed(
        uint256 indexed voucherId,
        uint256 indexed offeringId,
        address indexed provider
    );
    event VoucherRefunded(
        uint256 indexed voucherId,
        address indexed buyer,
        string reason
    );
    event ProviderWithdrawal(address indexed provider, uint256 amount);

    // ---------- Modifiers ----------
    modifier onlyProvider(uint256 offeringId) {
        require(
            offerings[offeringId].provider == msg.sender,
            "Not offering provider"
        );
        _;
    }

    modifier nonReentrant() {
        require(_locked == 0, "Reentrancy");
        _locked = 1;
        _;
        _locked = 0;
    }

    // ---------- Offering Management ----------
    function createOffering(
        uint256 price,
        uint256 validityPeriod,
        string calldata metadataURI
    ) external returns (uint256 offeringId) {
        require(price > 0, "Price=0");
        require(validityPeriod > 0, "Validity=0");

        offeringId = ++nextOfferingId;
        offerings[offeringId] = Offering({
            provider: msg.sender,
            price: price,
            validityPeriod: validityPeriod,
            active: true,
            metadataURI: metadataURI
        });

        emit OfferingCreated(
            offeringId,
            msg.sender,
            price,
            validityPeriod,
            metadataURI
        );
    }

    function updateOffering(
        uint256 offeringId,
        uint256 newPrice,
        uint256 newValidityPeriod,
        bool newActive,
        string calldata newMetadataURI
    ) external onlyProvider(offeringId) {
        require(newPrice > 0, "Price=0");
        require(newValidityPeriod > 0, "Validity=0");

        Offering storage o = offerings[offeringId];
        o.price = newPrice;
        o.validityPeriod = newValidityPeriod;
        o.active = newActive;
        o.metadataURI = newMetadataURI;

        emit OfferingUpdated(
            offeringId,
            newPrice,
            newValidityPeriod,
            newActive,
            newMetadataURI
        );
    }

    // ---------- Purchase ----------
    function buyVoucher(
        uint256 offeringId
    ) external payable nonReentrant returns (uint256 voucherId) {
        Offering storage o = offerings[offeringId];
        require(o.provider != address(0), "No offering");
        require(o.active, "Inactive offering");
        require(msg.value == o.price, "Wrong price");

        uint64 nowTs = uint64(block.timestamp);
        uint64 expiryTs = uint64(block.timestamp + o.validityPeriod);

        voucherId = ++nextVoucherId;
        vouchers[voucherId] = Voucher({
            offeringId: offeringId,
            buyer: msg.sender,
            purchaseTime: nowTs,
            expiry: expiryTs,
            redeemed: false,
            refunded: false
        });

        emit VoucherPurchased(
            voucherId,
            offeringId,
            msg.sender,
            o.price,
            expiryTs
        );
    }

    // ---------- Redeem (service provided) ----------
    function redeem(uint256 voucherId) external nonReentrant {
        Voucher storage v = vouchers[voucherId];
        require(v.buyer != address(0), "No voucher");
        Offering storage o = offerings[v.offeringId];
        require(msg.sender == o.provider, "Only provider");
        require(!v.redeemed, "Already redeemed");
        require(!v.refunded, "Already refunded");
        require(block.timestamp <= v.expiry, "Expired");

        v.redeemed = true;
        providerBalances[o.provider] += o.price;

        emit VoucherRedeemed(voucherId, v.offeringId, o.provider);
    }

    // ---------- Refunds ----------
    // Buyer can refund expired, unredeemed voucher.
    function refundExpired(uint256 voucherId) external nonReentrant {
        Voucher storage v = vouchers[voucherId];
        require(v.buyer != address(0), "No voucher");
        require(msg.sender == v.buyer, "Only buyer");
        require(!v.redeemed, "Already redeemed");
        require(!v.refunded, "Already refunded");
        require(block.timestamp > v.expiry, "Not expired");

        v.refunded = true;
        uint256 price = offerings[v.offeringId].price;

        (bool ok, ) = v.buyer.call{value: price}("");
        require(ok, "Refund failed");

        emit VoucherRefunded(voucherId, v.buyer, "expired");
    }

    // Provider-initiated refund (e.g., cancellation / unable to fulfill).
    function providerCancelAndRefund(uint256 voucherId) external nonReentrant {
        Voucher storage v = vouchers[voucherId];
        require(v.buyer != address(0), "No voucher");

        Offering storage o = offerings[v.offeringId];
        require(msg.sender == o.provider, "Only provider");
        require(!v.redeemed, "Already redeemed");
        require(!v.refunded, "Already refunded");

        v.refunded = true;
        uint256 price = o.price;

        (bool ok, ) = v.buyer.call{value: price}("");
        require(ok, "Refund failed");

        emit VoucherRefunded(voucherId, v.buyer, "provider_cancelled");
    }

    // ---------- Withdraw ----------
    function providerWithdraw(uint256 amount) external nonReentrant {
        require(amount > 0, "Amount=0");
        uint256 bal = providerBalances[msg.sender];
        require(bal >= amount, "Insufficient");

        providerBalances[msg.sender] = bal - amount;

        (bool ok, ) = msg.sender.call{value: amount}("");
        require(ok, "Withdraw failed");

        emit ProviderWithdrawal(msg.sender, amount);
    }

    // ---------- Views ----------
    function getOffering(
        uint256 offeringId
    )
        external
        view
        returns (
            address provider,
            uint256 price,
            uint256 validityPeriod,
            bool active,
            string memory metadataURI
        )
    {
        Offering storage o = offerings[offeringId];
        return (o.provider, o.price, o.validityPeriod, o.active, o.metadataURI);
    }

    function getVoucher(
        uint256 voucherId
    )
        external
        view
        returns (
            uint256 offeringId,
            address buyer,
            uint64 purchaseTime,
            uint64 expiry,
            bool redeemed,
            bool refunded
        )
    {
        Voucher storage v = vouchers[voucherId];
        return (
            v.offeringId,
            v.buyer,
            v.purchaseTime,
            v.expiry,
            v.redeemed,
            v.refunded
        );
    }
}
