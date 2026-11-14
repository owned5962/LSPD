-- Keep the ledger enum aligned with the transaction types emitted by rp_economy and rp_fuel.
ALTER TABLE `bank_transactions`
    MODIFY COLUMN `type` ENUM(
        'deposit',
        'withdraw',
        'transfer_send',
        'transfer_receive',
        'salary',
        'fuel_refund',
        'fuel'
    ) NOT NULL;
