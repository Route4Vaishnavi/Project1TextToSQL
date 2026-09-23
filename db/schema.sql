-- ===========================================================================
-- Text-to-SQL demo schema: a small but realistic e-commerce business.
--
-- DESIGN NOTE FOR THE READER
-- This schema is intentionally built so that plausible business questions are
-- genuinely ambiguous. "Best customer", "revenue", "new customer" and
-- "last month" each have more than one defensible SQL translation here.
-- That ambiguity is the subject of the whole project - see the clarification
-- engine in src/text2sql/core/clarifier.py
--
-- Every table and column carries a COMMENT. Those comments are fed to the
-- model as schema documentation, which measurably improves SQL accuracy.
-- ===========================================================================

DROP TABLE IF EXISTS refunds, payments, order_items, orders, sessions,
                     addresses, products, categories, customers CASCADE;

-- --------------------------------------------------------------------------
-- Customers
-- --------------------------------------------------------------------------
CREATE TABLE customers (
    customer_id   BIGSERIAL PRIMARY KEY,
    email         TEXT        NOT NULL UNIQUE,
    full_name     TEXT        NOT NULL,
    signup_date   DATE        NOT NULL,
    country       TEXT        NOT NULL,
    segment       TEXT        NOT NULL CHECK (segment IN ('consumer', 'business')),
    is_deleted    BOOLEAN     NOT NULL DEFAULT FALSE,
    created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE  customers IS
    'One row per registered customer account. Soft-deleted rows remain present with is_deleted = true and should normally be excluded.';
COMMENT ON COLUMN customers.signup_date IS
    'Date the account was created. NOTE: this is account creation, not first purchase. A "new customer" may mean either - ask before assuming.';
COMMENT ON COLUMN customers.is_deleted IS
    'Soft delete flag. Almost every business question should filter is_deleted = false.';
COMMENT ON COLUMN customers.segment IS
    'Either consumer (B2C) or business (B2B).';

-- --------------------------------------------------------------------------
-- Categories and products
-- --------------------------------------------------------------------------
CREATE TABLE categories (
    category_id   BIGSERIAL PRIMARY KEY,
    name          TEXT   NOT NULL UNIQUE,
    parent_id     BIGINT REFERENCES categories(category_id)
);

COMMENT ON TABLE categories IS
    'Product category hierarchy. parent_id is NULL for top-level categories.';

CREATE TABLE products (
    product_id    BIGSERIAL PRIMARY KEY,
    sku           TEXT          NOT NULL UNIQUE,
    name          TEXT          NOT NULL,
    category_id   BIGINT        NOT NULL REFERENCES categories(category_id),
    unit_price    NUMERIC(12,2) NOT NULL CHECK (unit_price >= 0),
    unit_cost     NUMERIC(12,2) NOT NULL CHECK (unit_cost >= 0),
    is_active     BOOLEAN       NOT NULL DEFAULT TRUE
);

COMMENT ON COLUMN products.unit_price IS
    'Current list price. The price actually charged is stored on order_items.unit_price and may differ due to discounts or price changes.';
COMMENT ON COLUMN products.unit_cost IS
    'Cost of goods. Use with unit_price to compute margin.';

-- --------------------------------------------------------------------------
-- Orders
-- --------------------------------------------------------------------------
CREATE TABLE orders (
    order_id        BIGSERIAL PRIMARY KEY,
    customer_id     BIGINT        NOT NULL REFERENCES customers(customer_id),
    placed_at       TIMESTAMPTZ   NOT NULL,
    status          TEXT          NOT NULL CHECK (status IN
                        ('pending','paid','shipped','delivered','cancelled','returned')),
    currency        CHAR(3)       NOT NULL DEFAULT 'USD',
    shipping_amount NUMERIC(12,2) NOT NULL DEFAULT 0,
    tax_amount      NUMERIC(12,2) NOT NULL DEFAULT 0,
    discount_amount NUMERIC(12,2) NOT NULL DEFAULT 0
);

COMMENT ON TABLE orders IS
    'One row per placed order, including orders that were later cancelled or returned.';
COMMENT ON COLUMN orders.status IS
    'Lifecycle status. Valid values: pending, paid, shipped, delivered, cancelled, returned. IMPORTANT: cancelled and returned orders are still rows here. Most revenue questions should exclude them, but "number of orders" may or may not - ask.';
COMMENT ON COLUMN orders.placed_at IS
    'Timestamp the order was submitted, in UTC.';
COMMENT ON COLUMN orders.discount_amount IS
    'Order-level discount already applied. Net order value = sum(order_items.line_total) + shipping_amount + tax_amount - discount_amount.';

CREATE TABLE order_items (
    order_item_id BIGSERIAL PRIMARY KEY,
    order_id      BIGINT        NOT NULL REFERENCES orders(order_id) ON DELETE CASCADE,
    product_id    BIGINT        NOT NULL REFERENCES products(product_id),
    quantity      INT           NOT NULL CHECK (quantity > 0),
    unit_price    NUMERIC(12,2) NOT NULL,
    line_total    NUMERIC(12,2) NOT NULL
);

COMMENT ON COLUMN order_items.unit_price IS
    'Price actually charged per unit at the time of sale. Use this, not products.unit_price, for historical revenue.';
COMMENT ON COLUMN order_items.line_total IS
    'quantity * unit_price, stored denormalised for query simplicity.';

-- --------------------------------------------------------------------------
-- Payments and refunds
-- --------------------------------------------------------------------------
CREATE TABLE payments (
    payment_id  BIGSERIAL PRIMARY KEY,
    order_id    BIGINT        NOT NULL REFERENCES orders(order_id),
    paid_at     TIMESTAMPTZ   NOT NULL,
    amount      NUMERIC(12,2) NOT NULL,
    status      TEXT          NOT NULL CHECK (status IN ('captured','failed','refunded')),
    method      TEXT          NOT NULL CHECK (method IN ('card','upi','netbanking','wallet','cod'))
);

COMMENT ON TABLE payments IS
    'Payment attempts against orders. A single order can have multiple attempts, including failures.';
COMMENT ON COLUMN payments.status IS
    'captured = money received. failed = attempt did not succeed. refunded = fully refunded. Revenue questions should normally count only status = captured.';

CREATE TABLE refunds (
    refund_id    BIGSERIAL PRIMARY KEY,
    payment_id   BIGINT        NOT NULL REFERENCES payments(payment_id),
    refunded_at  TIMESTAMPTZ   NOT NULL,
    amount       NUMERIC(12,2) NOT NULL,
    reason       TEXT          NOT NULL
);

COMMENT ON TABLE refunds IS
    'Partial or full refunds. NOTE: gross revenue ignores this table; net revenue subtracts it. "Revenue" alone is ambiguous - ask which.';

-- --------------------------------------------------------------------------
-- Sessions and addresses
-- --------------------------------------------------------------------------
CREATE TABLE sessions (
    session_id   BIGSERIAL PRIMARY KEY,
    customer_id  BIGINT      REFERENCES customers(customer_id),
    started_at   TIMESTAMPTZ NOT NULL,
    device       TEXT        NOT NULL CHECK (device IN ('web','ios','android'))
);

COMMENT ON TABLE sessions IS
    'Website and app visits. customer_id is NULL for anonymous sessions. This is the table to use for "repeat visits" or "most engaged customer".';

CREATE TABLE addresses (
    address_id   BIGSERIAL PRIMARY KEY,
    customer_id  BIGINT NOT NULL REFERENCES customers(customer_id),
    address_type TEXT   NOT NULL CHECK (address_type IN ('billing','shipping')),
    city         TEXT   NOT NULL,
    country      TEXT   NOT NULL
);

COMMENT ON TABLE addresses IS
    'Customer addresses. A customer may have several. customers.country is the account country and may differ from the shipping country.';

-- --------------------------------------------------------------------------
-- Indexes: these matter once the seed data grows, and interviewers ask why.
-- --------------------------------------------------------------------------
CREATE INDEX idx_orders_customer     ON orders(customer_id);
CREATE INDEX idx_orders_placed_at    ON orders(placed_at);
CREATE INDEX idx_orders_status       ON orders(status);
CREATE INDEX idx_order_items_order   ON order_items(order_id);
CREATE INDEX idx_order_items_product ON order_items(product_id);
CREATE INDEX idx_payments_order      ON payments(order_id);
CREATE INDEX idx_payments_paid_at    ON payments(paid_at);
CREATE INDEX idx_sessions_customer   ON sessions(customer_id, started_at);
CREATE INDEX idx_customers_signup    ON customers(signup_date);
