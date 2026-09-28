-- ================================================================
-- DATABASE: Integrasi ERP, SCM & CRM — PT Indofood CBP
-- DBMS    : MySQL 8.0+
-- Deskripsi: Struktur database untuk dashboard analisis integrasi
--            proses bisnis menghadapi lonjakan Ramadan Q1 2026
-- ================================================================

CREATE DATABASE IF NOT EXISTS indofood_erp_dashboard
    CHARACTER SET utf8mb4
    COLLATE utf8mb4_unicode_ci;

USE indofood_erp_dashboard;

-- ================================================================
-- TABEL REFERENSI (MASTER DATA)
-- ================================================================

-- Produk yang diproduksi
CREATE TABLE products (
    product_id      INT AUTO_INCREMENT PRIMARY KEY,
    product_code    VARCHAR(20)  NOT NULL UNIQUE,
    product_name    VARCHAR(100) NOT NULL,
    category        VARCHAR(50)  NOT NULL DEFAULT 'Instant Noodles',
    unit            VARCHAR(20)  NOT NULL DEFAULT 'Karton',
    unit_price      DECIMAL(12,2) NOT NULL,
    safety_stock    INT           NOT NULL DEFAULT 5000,
    reorder_point   INT           NOT NULL DEFAULT 5000,
    created_at      TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at      TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB;

-- Distributor / pelanggan B2B
CREATE TABLE distributors (
    distributor_id   INT AUTO_INCREMENT PRIMARY KEY,
    distributor_code VARCHAR(20)  NOT NULL UNIQUE,
    name             VARCHAR(150) NOT NULL,
    tier             ENUM('Tier-1','Tier-2','Tier-3') NOT NULL DEFAULT 'Tier-2',
    region           VARCHAR(50)  NOT NULL,
    province         VARCHAR(50)  NOT NULL,
    contact_person   VARCHAR(100),
    phone            VARCHAR(20),
    email            VARCHAR(100),
    is_active        BOOLEAN NOT NULL DEFAULT TRUE,
    created_at       TIMESTAMP DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB;

-- Pemasok bahan baku
CREATE TABLE suppliers (
    supplier_id    INT AUTO_INCREMENT PRIMARY KEY,
    supplier_code  VARCHAR(20)  NOT NULL UNIQUE,
    name           VARCHAR(150) NOT NULL,
    material_type  VARCHAR(80)  NOT NULL COMMENT 'Tepung Terigu, Bumbu, Kemasan, dll.',
    lead_time_days INT          NOT NULL DEFAULT 3,
    region         VARCHAR(50),
    contact_person VARCHAR(100),
    phone          VARCHAR(20),
    is_active      BOOLEAN NOT NULL DEFAULT TRUE,
    created_at     TIMESTAMP DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB;

-- Armada logistik
CREATE TABLE fleet (
    fleet_id      INT AUTO_INCREMENT PRIMARY KEY,
    vehicle_code  VARCHAR(20)  NOT NULL UNIQUE,
    vehicle_type  ENUM('Truck','Container','Van') NOT NULL DEFAULT 'Truck',
    ownership     ENUM('Reguler','Sewa Ekstra') NOT NULL DEFAULT 'Reguler',
    capacity_kg   DECIMAL(10,2) NOT NULL,
    region_base   VARCHAR(50),
    is_active     BOOLEAN NOT NULL DEFAULT TRUE,
    rent_cost_per_day DECIMAL(12,2) DEFAULT NULL COMMENT 'NULL jika milik sendiri',
    created_at    TIMESTAMP DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB;


-- ================================================================
-- MODUL CRM — Customer Relationship Management
-- ================================================================

-- Pesanan dari distributor (Sales Order)
CREATE TABLE crm_orders (
    order_id        INT AUTO_INCREMENT PRIMARY KEY,
    order_number    VARCHAR(30)  NOT NULL UNIQUE,
    order_date      DATE         NOT NULL,
    distributor_id  INT          NOT NULL,
    product_id      INT          NOT NULL,
    quantity        INT          NOT NULL COMMENT 'Dalam satuan karton',
    unit_price      DECIMAL(12,2) NOT NULL,
    total_amount    DECIMAL(15,2) GENERATED ALWAYS AS (quantity * unit_price) STORED,
    status          ENUM('Pending','Confirmed','In Production','Shipped','Delivered','Cancelled')
                        NOT NULL DEFAULT 'Pending',
    priority        ENUM('Normal','High','Urgent') NOT NULL DEFAULT 'Normal',
    notes           TEXT,
    created_at      TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at      TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

    FOREIGN KEY (distributor_id) REFERENCES distributors(distributor_id),
    FOREIGN KEY (product_id)     REFERENCES products(product_id),

    INDEX idx_order_date (order_date),
    INDEX idx_status (status)
) ENGINE=InnoDB;

-- Interaksi / feedback pelanggan
CREATE TABLE crm_interactions (
    interaction_id  INT AUTO_INCREMENT PRIMARY KEY,
    distributor_id  INT          NOT NULL,
    interaction_date DATE        NOT NULL,
    channel         ENUM('Phone','Email','Visit','WhatsApp') NOT NULL,
    subject         VARCHAR(200),
    sentiment       ENUM('Positive','Neutral','Negative') DEFAULT 'Neutral',
    notes           TEXT,
    handled_by      VARCHAR(100),
    created_at      TIMESTAMP DEFAULT CURRENT_TIMESTAMP,

    FOREIGN KEY (distributor_id) REFERENCES distributors(distributor_id)
) ENGINE=InnoDB;


-- ================================================================
-- MODUL ERP — Enterprise Resource Planning
-- ================================================================

-- Rencana produksi (Production Plan / MPS)
CREATE TABLE erp_production_plans (
    plan_id         INT AUTO_INCREMENT PRIMARY KEY,
    plan_date       DATE         NOT NULL,
    product_id      INT          NOT NULL,
    target_quantity INT          NOT NULL COMMENT 'Target produksi (karton)',
    actual_quantity INT          DEFAULT NULL COMMENT 'Realisasi produksi (karton)',
    shift_count     TINYINT      NOT NULL DEFAULT 2 COMMENT 'Jumlah shift operasional',
    oee_percentage  DECIMAL(5,2) DEFAULT NULL COMMENT 'Overall Equipment Effectiveness (%)',
    status          ENUM('Planned','In Progress','Completed','Overtime') NOT NULL DEFAULT 'Planned',
    overtime_hours  DECIMAL(5,2) DEFAULT 0,
    overtime_cost   DECIMAL(12,2) DEFAULT 0,
    notes           TEXT,
    created_at      TIMESTAMP DEFAULT CURRENT_TIMESTAMP,

    FOREIGN KEY (product_id) REFERENCES products(product_id),
    INDEX idx_plan_date (plan_date)
) ENGINE=InnoDB;

-- Stok gudang (Inventory)
CREATE TABLE erp_inventory (
    inventory_id    INT AUTO_INCREMENT PRIMARY KEY,
    record_date     DATE         NOT NULL,
    product_id      INT          NOT NULL,
    opening_stock   INT          NOT NULL,
    produced        INT          NOT NULL DEFAULT 0,
    shipped         INT          NOT NULL DEFAULT 0,
    closing_stock   INT          GENERATED ALWAYS AS (opening_stock + produced - shipped) STORED,
    status          ENUM('Normal','Low','Critical') NOT NULL DEFAULT 'Normal',
    created_at      TIMESTAMP DEFAULT CURRENT_TIMESTAMP,

    FOREIGN KEY (product_id) REFERENCES products(product_id),
    INDEX idx_record_date (record_date),

    CONSTRAINT chk_closing UNIQUE (record_date, product_id)
) ENGINE=InnoDB;

-- Permintaan pengadaan bahan baku (Purchase Requisition)
CREATE TABLE erp_purchase_requisitions (
    pr_id           INT AUTO_INCREMENT PRIMARY KEY,
    pr_number       VARCHAR(30)  NOT NULL UNIQUE,
    request_date    DATE         NOT NULL,
    product_id      INT          NOT NULL,
    supplier_id     INT          NOT NULL,
    material_desc   VARCHAR(200) NOT NULL,
    quantity_needed DECIMAL(12,2) NOT NULL,
    unit            VARCHAR(20)  NOT NULL DEFAULT 'Ton',
    urgency         ENUM('Normal','Urgent','Emergency') NOT NULL DEFAULT 'Normal',
    status          ENUM('Draft','Approved','Ordered','Received','Cancelled') NOT NULL DEFAULT 'Draft',
    triggered_by    ENUM('Manual','Auto-Reorder','ERP-SCM Integration') NOT NULL DEFAULT 'Manual',
    estimated_cost  DECIMAL(15,2),
    created_at      TIMESTAMP DEFAULT CURRENT_TIMESTAMP,

    FOREIGN KEY (product_id)  REFERENCES products(product_id),
    FOREIGN KEY (supplier_id) REFERENCES suppliers(supplier_id),
    INDEX idx_request_date (request_date)
) ENGINE=InnoDB;


-- ================================================================
-- MODUL SCM — Supply Chain Management
-- ================================================================

-- Pengiriman / Shipment
CREATE TABLE scm_shipments (
    shipment_id     INT AUTO_INCREMENT PRIMARY KEY,
    shipment_number VARCHAR(30) NOT NULL UNIQUE,
    order_id        INT         NOT NULL,
    fleet_id        INT         NOT NULL,
    ship_date       DATE        NOT NULL,
    delivery_date   DATE        DEFAULT NULL,
    origin          VARCHAR(100) NOT NULL DEFAULT 'Gudang Pusat - Tangerang',
    destination     VARCHAR(150) NOT NULL,
    quantity        INT          NOT NULL,
    status          ENUM('Preparing','In Transit','Delivered','Delayed','Returned')
                        NOT NULL DEFAULT 'Preparing',
    delivery_cost   DECIMAL(12,2),
    is_on_time      BOOLEAN DEFAULT NULL,
    notes           TEXT,
    created_at      TIMESTAMP DEFAULT CURRENT_TIMESTAMP,

    FOREIGN KEY (order_id) REFERENCES crm_orders(order_id),
    FOREIGN KEY (fleet_id) REFERENCES fleet(fleet_id),
    INDEX idx_ship_date (ship_date)
) ENGINE=InnoDB;

-- Log pengadaan armada ekstra
CREATE TABLE scm_fleet_procurement (
    procurement_id  INT AUTO_INCREMENT PRIMARY KEY,
    procurement_date DATE        NOT NULL,
    vendor_name     VARCHAR(150) NOT NULL,
    vehicle_count   INT          NOT NULL,
    cost_per_day    DECIMAL(12,2) NOT NULL,
    contract_days   INT          NOT NULL,
    total_cost      DECIMAL(15,2) GENERATED ALWAYS AS (vehicle_count * cost_per_day * contract_days) STORED,
    reason          VARCHAR(200) DEFAULT 'Pengadaan darurat lonjakan Ramadan',
    status          ENUM('Active','Expired','Cancelled') NOT NULL DEFAULT 'Active',
    created_at      TIMESTAMP DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB;

-- KPI Harian SCM
CREATE TABLE scm_daily_kpi (
    kpi_id              INT AUTO_INCREMENT PRIMARY KEY,
    record_date         DATE NOT NULL,
    total_shipments     INT  NOT NULL DEFAULT 0,
    on_time_deliveries  INT  NOT NULL DEFAULT 0,
    delayed_deliveries  INT  NOT NULL DEFAULT 0,
    otd_rate            DECIMAL(5,2) GENERATED ALWAYS AS (
                            CASE WHEN total_shipments > 0
                                THEN (on_time_deliveries / total_shipments) * 100
                                ELSE 0 END
                        ) STORED,
    fleet_regular_used  INT  NOT NULL DEFAULT 0,
    fleet_extra_used    INT  NOT NULL DEFAULT 0,
    total_delivery_cost DECIMAL(15,2) DEFAULT 0,
    created_at          TIMESTAMP DEFAULT CURRENT_TIMESTAMP,

    UNIQUE INDEX idx_record_date (record_date)
) ENGINE=InnoDB;


-- ================================================================
-- VIEW — Ringkasan Lintas Modul (untuk dashboard query)
-- ================================================================

CREATE OR REPLACE VIEW v_dashboard_summary AS
SELECT
    inv.record_date,
    -- CRM Metrics
    COALESCE(crm.total_orders, 0)       AS crm_total_orders,
    COALESCE(crm.total_quantity, 0)     AS crm_total_quantity,
    -- ERP Metrics
    COALESCE(pp.target_quantity, 0)     AS erp_target_production,
    COALESCE(pp.actual_quantity, 0)     AS erp_actual_production,
    COALESCE(pp.oee_percentage, 0)     AS erp_oee,
    inv.closing_stock                   AS erp_closing_stock,
    inv.status                          AS erp_stock_status,
    -- SCM Metrics
    COALESCE(scm.total_shipments, 0)   AS scm_total_shipments,
    COALESCE(scm.otd_rate, 0)          AS scm_otd_rate
FROM erp_inventory inv
LEFT JOIN (
    SELECT order_date,
           COUNT(*)    AS total_orders,
           SUM(quantity) AS total_quantity
    FROM crm_orders
    GROUP BY order_date
) crm ON crm.order_date = inv.record_date
LEFT JOIN erp_production_plans pp
    ON pp.plan_date = inv.record_date AND pp.product_id = inv.product_id
LEFT JOIN scm_daily_kpi scm
    ON scm.record_date = inv.record_date
ORDER BY inv.record_date;


-- ================================================================
-- SEED DATA — Simulasi Q1 2026 (sesuai dashboard)
-- ================================================================

-- Produk
INSERT INTO products (product_code, product_name, category, unit, unit_price, safety_stock, reorder_point) VALUES
('IDM-GRG-001', 'Indomie Goreng Original',     'Instant Noodles', 'Karton', 95000.00, 5000, 5000),
('IDM-KUA-001', 'Indomie Kuah Soto',           'Instant Noodles', 'Karton', 92000.00, 3000, 3500),
('IDM-KUA-002', 'Indomie Kuah Kari Ayam',      'Instant Noodles', 'Karton', 92000.00, 3000, 3500);

-- Distributor
INSERT INTO distributors (distributor_code, name, tier, region, province) VALUES
('DST-001', 'PT Inti Cakrawala Citra',   'Tier-1', 'Jawa Barat',   'Jawa Barat'),
('DST-002', 'PT Indomarco Prismatama',   'Tier-1', 'DKI Jakarta',  'DKI Jakarta'),
('DST-003', 'CV Sumber Rezeki',          'Tier-2', 'Jawa Tengah',  'Jawa Tengah'),
('DST-004', 'PT Tigaraksa Satria',       'Tier-1', 'Jawa Timur',   'Jawa Timur'),
('DST-005', 'CV Makmur Jaya',            'Tier-2', 'Sumatera Utara','Sumatera Utara');

-- Supplier
INSERT INTO suppliers (supplier_code, name, material_type, lead_time_days, region) VALUES
('SUP-001', 'PT Indofood Sukses Makmur (Bogasari)', 'Tepung Terigu',  2, 'DKI Jakarta'),
('SUP-002', 'PT Bina Karya Perkasa',                 'Bumbu & Seasoning', 3, 'Jawa Barat'),
('SUP-003', 'PT Pindo Deli Pulp & Paper',            'Kemasan',         4, 'Jawa Barat');

-- Armada Reguler (sample 5 dari 150)
INSERT INTO fleet (vehicle_code, vehicle_type, ownership, capacity_kg, region_base) VALUES
('FLT-R001', 'Truck',     'Reguler', 8000,  'Tangerang'),
('FLT-R002', 'Truck',     'Reguler', 8000,  'Tangerang'),
('FLT-R003', 'Container', 'Reguler', 20000, 'Tangerang'),
('FLT-R004', 'Truck',     'Reguler', 8000,  'Surabaya'),
('FLT-R005', 'Van',       'Reguler', 3000,  'Bandung');

-- Armada Sewa Ekstra (sample 3 dari 50)
INSERT INTO fleet (vehicle_code, vehicle_type, ownership, capacity_kg, region_base, rent_cost_per_day) VALUES
('FLT-E001', 'Truck', 'Sewa Ekstra', 8000, 'Tangerang', 2500000),
('FLT-E002', 'Truck', 'Sewa Ekstra', 8000, 'Semarang',  2200000),
('FLT-E003', 'Truck', 'Sewa Ekstra', 8000, 'Surabaya',  2400000);

-- CRM Orders (sesuai data dashboard)
INSERT INTO crm_orders (order_number, order_date, distributor_id, product_id, quantity, unit_price, status, priority) VALUES
('SO-2026-0110-001', '2026-01-10', 1, 1, 2500, 95000, 'Delivered', 'Normal'),
('SO-2026-0110-002', '2026-01-10', 2, 1, 2500, 95000, 'Delivered', 'Normal'),
('SO-2026-0115-001', '2026-01-15', 3, 1, 3000, 95000, 'Delivered', 'Normal'),
('SO-2026-0202-001', '2026-02-02', 1, 1, 5000, 95000, 'Delivered', 'High'),
('SO-2026-0202-002', '2026-02-02', 4, 1, 7000, 95000, 'Delivered', 'High'),
('SO-2026-0214-001', '2026-02-14', 2, 1, 8000, 95000, 'Shipped',   'Urgent'),
('SO-2026-0214-002', '2026-02-14', 1, 1, 7000, 95000, 'Shipped',   'Urgent'),
('SO-2026-0305-001', '2026-03-05', 3, 1, 4000, 95000, 'In Production', 'High'),
('SO-2026-0305-002', '2026-03-05', 5, 1, 4000, 95000, 'In Production', 'High'),
('SO-2026-0312-001', '2026-03-12', 1, 1, 8000, 95000, 'Confirmed', 'Urgent'),
('SO-2026-0312-002', '2026-03-12', 4, 1, 7000, 95000, 'Confirmed', 'Urgent'),
('SO-2026-0312-003', '2026-03-12', 2, 1, 5000, 95000, 'Confirmed', 'Urgent');

-- ERP Production Plans
INSERT INTO erp_production_plans (plan_date, product_id, target_quantity, actual_quantity, shift_count, oee_percentage, status, overtime_hours, overtime_cost) VALUES
('2026-01-10', 1, 10000,  9800, 2, 82.5, 'Completed', 0,    0),
('2026-01-15', 1,  5000,  4900, 2, 80.0, 'Completed', 0,    0),
('2026-02-02', 1, 15000, 14500, 3, 85.0, 'Completed', 4, 1200000),
('2026-02-14', 1, 20000, 19200, 3, 88.5, 'Overtime',  8, 2800000),
('2026-03-05', 1, 10000,  9600, 2, 83.0, 'Completed', 2,  600000),
('2026-03-12', 1, 25000, 24000, 3, 91.0, 'In Progress', 8, 2800000);

-- ERP Inventory
INSERT INTO erp_inventory (record_date, product_id, opening_stock, produced, shipped, status) VALUES
('2026-01-10', 1, 20000,  9800,  4800, 'Normal'),
('2026-01-15', 1, 25000,  4900, 17900, 'Normal'),
('2026-02-02', 1, 12000, 14500, 11500, 'Normal'),
('2026-02-14', 1, 15000, 19200, 30200, 'Critical'),
('2026-03-05', 1,  4000,  9600,  5600, 'Low'),
('2026-03-12', 1, 18000, 24000, 20000, 'Normal');

-- ERP Purchase Requisitions
INSERT INTO erp_purchase_requisitions (pr_number, request_date, product_id, supplier_id, material_desc, quantity_needed, unit, urgency, status, triggered_by, estimated_cost) VALUES
('PR-2026-0201', '2026-02-01', 1, 1, 'Tepung Terigu Cakra Kembar',  500, 'Ton', 'Urgent',    'Approved', 'ERP-SCM Integration', 3500000000),
('PR-2026-0213', '2026-02-13', 1, 1, 'Tepung Terigu Cakra Kembar',  800, 'Ton', 'Emergency', 'Ordered',  'Auto-Reorder',         5600000000),
('PR-2026-0213B','2026-02-13', 1, 2, 'Bumbu Indomie Goreng',        200, 'Ton', 'Emergency', 'Ordered',  'Auto-Reorder',          800000000),
('PR-2026-0310', '2026-03-10', 1, 3, 'Kemasan Karton & Etiket',  500000, 'Pcs', 'Urgent',    'Approved', 'ERP-SCM Integration',   750000000);

-- SCM Fleet Procurement
INSERT INTO scm_fleet_procurement (procurement_date, vendor_name, vehicle_count, cost_per_day, contract_days, reason) VALUES
('2026-02-10', 'PT Rental Armada Nusantara', 30, 2500000, 45, 'Pengadaan darurat lonjakan Ramadan'),
('2026-02-15', 'CV Logistik Express',         20, 2200000, 30, 'Backup armada distribusi Jawa Timur');

-- SCM Shipments (sample)
INSERT INTO scm_shipments (shipment_number, order_id, fleet_id, ship_date, delivery_date, destination, quantity, status, delivery_cost, is_on_time) VALUES
('SHP-2026-0111-001', 1, 1, '2026-01-11', '2026-01-12', 'Bandung, Jawa Barat',   2500, 'Delivered', 3500000, TRUE),
('SHP-2026-0111-002', 2, 3, '2026-01-11', '2026-01-12', 'Jakarta Utara',          2500, 'Delivered', 2800000, TRUE),
('SHP-2026-0116-001', 3, 2, '2026-01-16', '2026-01-17', 'Semarang, Jawa Tengah',  3000, 'Delivered', 4200000, TRUE),
('SHP-2026-0204-001', 4, 1, '2026-02-04', '2026-02-05', 'Bandung, Jawa Barat',    5000, 'Delivered', 5500000, TRUE),
('SHP-2026-0204-002', 5, 4, '2026-02-04', '2026-02-06', 'Surabaya, Jawa Timur',   7000, 'Delivered', 8500000, FALSE),
('SHP-2026-0216-001', 6, 6, '2026-02-16', '2026-02-17', 'Jakarta Utara',          8000, 'Delivered', 6000000, TRUE),
('SHP-2026-0216-002', 7, 7, '2026-02-16', '2026-02-18', 'Bandung, Jawa Barat',    7000, 'In Transit', 5500000, NULL);

-- SCM Daily KPI
INSERT INTO scm_daily_kpi (record_date, total_shipments, on_time_deliveries, delayed_deliveries, fleet_regular_used, fleet_extra_used, total_delivery_cost) VALUES
('2026-01-11', 5,  5, 0, 5,  0, 12000000),
('2026-01-16', 3,  3, 0, 3,  0,  8500000),
('2026-02-04', 12, 11, 1, 10, 2, 35000000),
('2026-02-16', 18, 17, 1, 12, 6, 58000000),
('2026-03-06', 15, 15, 0, 10, 5, 45000000),
('2026-03-13', 22, 21, 1, 14, 8, 72000000);


-- ================================================================
-- STORED PROCEDURE — Rekapitulasi Dashboard
-- ================================================================

DELIMITER //

CREATE PROCEDURE sp_get_dashboard_data(IN p_start_date DATE, IN p_end_date DATE)
BEGIN
    -- 1. CRM Summary
    SELECT 'CRM' AS module,
           order_date,
           SUM(quantity) AS total_quantity,
           COUNT(*)      AS total_orders
    FROM crm_orders
    WHERE order_date BETWEEN p_start_date AND p_end_date
    GROUP BY order_date
    ORDER BY order_date;

    -- 2. ERP Summary
    SELECT 'ERP' AS module,
           pp.plan_date,
           pp.target_quantity,
           pp.actual_quantity,
           pp.oee_percentage,
           inv.closing_stock,
           inv.status AS stock_status
    FROM erp_production_plans pp
    JOIN erp_inventory inv ON inv.record_date = pp.plan_date AND inv.product_id = pp.product_id
    WHERE pp.plan_date BETWEEN p_start_date AND p_end_date
    ORDER BY pp.plan_date;

    -- 3. SCM Summary
    SELECT 'SCM' AS module,
           record_date,
           total_shipments,
           on_time_deliveries,
           otd_rate,
           fleet_regular_used,
           fleet_extra_used,
           total_delivery_cost
    FROM scm_daily_kpi
    WHERE record_date BETWEEN p_start_date AND p_end_date
    ORDER BY record_date;
END //

DELIMITER ;

-- ================================================================
-- CONTOH PEMANGGILAN
-- ================================================================
-- CALL sp_get_dashboard_data('2026-01-01', '2026-03-31');
-- SELECT * FROM v_dashboard_summary;
