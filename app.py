"""
Dashboard Integrasi ERP, SCM & CRM — PT Indofood CBP
=====================================================
Aplikasi Streamlit untuk analisis end-to-end proses bisnis
menghadapi lonjakan permintaan Indomie menjelang Ramadan Q1 2026.

Jalankan: streamlit run app.py
"""

import streamlit as st
import plotly.graph_objects as go
import plotly.express as px
import pandas as pd
import mysql.connector
from mysql.connector import Error
from contextlib import contextmanager

# ================================================================
# KONFIGURASI HALAMAN
# ================================================================
st.set_page_config(
    page_title="Dashboard Integrasi ERP, SCM & CRM — PT Indofood CBP",
    page_icon="📊",
    layout="wide",
    initial_sidebar_state="collapsed"
)

# ================================================================
# KONEKSI DATABASE (OPSIONAL)
# ================================================================
DB_CONFIG = {
    "host": "localhost",
    "port": 3306,
    "user": "root",
    "password": "",  # Ganti sesuai password MySQL Anda
    "database": "indofood_erp_dashboard",
}

USE_DATABASE = False  # Set True jika sudah mengimpor database.sql


@contextmanager
def get_db_connection():
    """Context manager untuk koneksi MySQL."""
    conn = None
    try:
        conn = mysql.connector.connect(**DB_CONFIG)
        yield conn
    except Error as e:
        st.warning(f"⚠️ Koneksi database gagal: {e}. Menggunakan data simulasi.")
        yield None
    finally:
        if conn and conn.is_connected():
            conn.close()


def fetch_crm_data_db(conn):
    """Ambil data CRM dari database."""
    query = """
        SELECT order_date, SUM(quantity) AS total_quantity, COUNT(*) AS total_orders
        FROM crm_orders
        WHERE order_date BETWEEN '2026-01-01' AND '2026-03-31'
        GROUP BY order_date
        ORDER BY order_date
    """
    return pd.read_sql(query, conn)


def fetch_erp_data_db(conn):
    """Ambil data ERP dari database."""
    query = """
        SELECT pp.plan_date, pp.target_quantity, pp.oee_percentage,
               inv.closing_stock, inv.status AS stock_status
        FROM erp_production_plans pp
        JOIN erp_inventory inv ON inv.record_date = pp.plan_date AND inv.product_id = pp.product_id
        WHERE pp.plan_date BETWEEN '2026-01-01' AND '2026-03-31'
        ORDER BY pp.plan_date
    """
    return pd.read_sql(query, conn)


def fetch_scm_data_db(conn):
    """Ambil data SCM dari database."""
    query = """
        SELECT SUM(CASE WHEN ownership='Reguler' THEN 1 ELSE 0 END) AS reguler,
               SUM(CASE WHEN ownership='Sewa Ekstra' THEN 1 ELSE 0 END) AS sewa_ekstra
        FROM fleet
        WHERE is_active = TRUE
    """
    return pd.read_sql(query, conn)


# ================================================================
# DATA SIMULASI (HARDCODED — fallback jika DB tidak tersedia)
# ================================================================
LABELS = ["10-Jan", "15-Jan", "02-Feb", "14-Feb", "05-Mar", "12-Mar"]

CRM_DATA = pd.DataFrame({
    "tanggal": LABELS,
    "volume_pesanan": [5000, 3000, 12000, 15000, 8000, 20000]
})

ERP_DATA = pd.DataFrame({
    "tanggal": LABELS,
    "target_produksi": [10000, 5000, 15000, 20000, 10000, 25000],
    "sisa_stok": [25000, 12000, 15000, 4000, 18000, 22000]
})

SCM_DATA = pd.DataFrame({
    "tipe": ["Armada Reguler", "Truk Sewa Ekstra"],
    "jumlah": [150, 50]
})

# ================================================================
# LOAD DATA (dari DB atau Simulasi)
# ================================================================
if USE_DATABASE:
    with get_db_connection() as conn:
        if conn:
            try:
                crm_df = fetch_crm_data_db(conn)
                erp_df = fetch_erp_data_db(conn)
                scm_df = fetch_scm_data_db(conn)
                st.sidebar.success("✅ Data diambil dari MySQL")
            except Exception:
                crm_df, erp_df, scm_df = CRM_DATA, ERP_DATA, SCM_DATA
                st.sidebar.info("ℹ️ Menggunakan data simulasi")
        else:
            crm_df, erp_df, scm_df = CRM_DATA, ERP_DATA, SCM_DATA
else:
    crm_df, erp_df, scm_df = CRM_DATA, ERP_DATA, SCM_DATA


# ================================================================
# CUSTOM CSS
# ================================================================
st.markdown("""
<style>
    /* Header */
    .main-header {
        background: linear-gradient(135deg, #1e3a5f 0%, #0f172a 100%);
        color: white;
        padding: 2.5rem 2rem;
        border-radius: 16px;
        margin-bottom: 2rem;
        text-align: center;
    }
    .main-header h1 { font-size: 2rem; margin-bottom: .4rem; }
    .main-header p { color: #94a3b8; font-size: 1rem; }

    /* Badge row */
    .badge-row { display: flex; justify-content: center; gap: 12px; margin-top: 16px; flex-wrap: wrap; }
    .badge {
        padding: 6px 18px; border-radius: 999px; font-size: .82rem;
        font-weight: 600; letter-spacing: .3px; display: inline-block;
    }
    .badge-crm { background: rgba(59,130,246,.2); color: #93c5fd; }
    .badge-erp { background: rgba(245,158,11,.2); color: #fcd34d; }
    .badge-scm { background: rgba(16,185,129,.2); color: #6ee7b7; }

    /* Section title */
    .section-title {
        display: flex; align-items: center; gap: 12px;
        margin-bottom: 8px; margin-top: 2rem;
    }
    .section-title .dot {
        width: 14px; height: 14px; border-radius: 50%; flex-shrink: 0;
    }
    .section-title h2 { font-size: 1.3rem; margin: 0; }
    .section-title .label { font-size: .82rem; color: #64748b; }

    /* Insight box */
    .insight-box {
        border-radius: 12px; padding: 22px 24px;
        font-size: .9rem; line-height: 1.75;
    }
    .insight-crm {
        background: linear-gradient(135deg, #eff6ff, #dbeafe);
        border-left: 5px solid #3b82f6; color: #1e3a5f;
    }
    .insight-erp {
        background: linear-gradient(135deg, #fffbeb, #fef3c7);
        border-left: 5px solid #f59e0b; color: #78350f;
    }
    .insight-scm {
        background: linear-gradient(135deg, #ecfdf5, #d1fae5);
        border-left: 5px solid #10b981; color: #064e3b;
    }

    /* Flow arrow */
    .flow-arrow {
        text-align: center; padding: 20px 0; color: #64748b;
        font-size: .85rem; font-weight: 600; letter-spacing: 1px;
    }

    /* Summary banner */
    .summary-card {
        background: linear-gradient(135deg, #0f172a 0%, #1e3a5f 100%);
        color: white; border-radius: 16px; padding: 28px 32px;
        margin: 2rem 0;
    }
    .summary-card h3 { color: #e2e8f0; margin-bottom: 12px; }
    .summary-card p { color: #94a3b8; line-height: 1.8; font-size: .92rem; }

    /* KPI metric override */
    [data-testid="stMetric"] {
        background: white; border: 1px solid #e2e8f0;
        border-radius: 12px; padding: 16px 20px;
        box-shadow: 0 2px 12px rgba(0,0,0,.04);
    }
</style>
""", unsafe_allow_html=True)

# ================================================================
# HEADER
# ================================================================
st.markdown("""
<div class="main-header">
    <h1>📊 Dashboard Integrasi ERP, SCM &amp; CRM</h1>
    <p>Analisis End-to-End Proses Bisnis <strong>PT Indofood CBP Sukses Makmur</strong> —
       Lonjakan Permintaan <em>Indomie</em> Menjelang Ramadan (Q1 2026)</p>
    <div class="badge-row">
        <span class="badge badge-crm">🎯 CRM — Ujung Tombak</span>
        <span class="badge badge-erp">🏭 ERP — Dapur Operasional</span>
        <span class="badge badge-scm">🚛 SCM — Tulang Punggung</span>
    </div>
</div>
""", unsafe_allow_html=True)

# ================================================================
# BAGIAN A — CRM
# ================================================================
st.markdown("""
<div class="section-title">
    <div class="dot" style="background: #3b82f6;"></div>
    <div>
        <h2>Bagian A: CRM — Customer Relationship Management</h2>
        <span class="label">Ujung Tombak Penjualan &amp; Demand Sensing</span>
    </div>
</div>
""", unsafe_allow_html=True)

# KPI Row CRM
k1, k2, k3, k4 = st.columns(4)
k1.metric("Total Pesanan", "63.000 Karton", "+300% dari baseline")
k2.metric("Distributor Aktif", "47", "+12 distributor baru")
k3.metric("Pesanan Puncak", "20.000 Karton", "4x rata-rata harian")
k4.metric("Tingkat Retensi", "98.2%", "Stabil ✓")

# Chart + Insight
col_chart, col_insight = st.columns([1.2, 1])

with col_chart:
    fig_crm = go.Figure()
    fig_crm.add_trace(go.Scatter(
        x=crm_df["tanggal"],
        y=crm_df["volume_pesanan"],
        mode="lines+markers",
        name="Volume Pesanan (Karton)",
        line=dict(color="#3b82f6", width=3, shape="spline"),
        marker=dict(size=10, color="#3b82f6", line=dict(width=2, color="white")),
        fill="tozeroy",
        fillcolor="rgba(59,130,246,0.1)",
        hovertemplate="Tanggal: %{x}<br>Pesanan: %{y:,.0f} karton<extra></extra>"
    ))
    fig_crm.update_layout(
        title="📈 Tren Volume Pesanan Distributor (Q1 2026)",
        xaxis_title="Tanggal",
        yaxis_title="Jumlah Karton",
        template="plotly_white",
        height=400,
        margin=dict(t=50, b=40),
        yaxis=dict(tickformat=","),
    )
    st.plotly_chart(fig_crm, use_container_width=True)

with col_insight:
    st.markdown("""
    <div class="insight-box insight-crm">
        <strong>🔍 Insight Integrasi CRM</strong><br><br>
        Data CRM menunjukkan pola <strong>seasonal spike</strong> yang konsisten: pesanan melonjak
        dari <strong>5.000 karton</strong> di awal Januari menjadi <strong>20.000 karton</strong>
        pada 12 Maret 2026 — peningkatan <strong>300%</strong> dalam 2 bulan.
        <ul>
            <li><strong>Demand Sensing:</strong> Sistem CRM mendeteksi anomali permintaan sejak
                2 Februari (12.000 karton), memberi lead time ~6 minggu bagi ERP.</li>
            <li><strong>Trigger ke ERP:</strong> Data pesanan CRM ter-<em>feed</em> ke modul
                <strong>MPS (Master Production Schedule)</strong> ERP melalui integrasi API.</li>
            <li><strong>Customer Segmentation:</strong> 70% lonjakan berasal dari distributor
                Tier-1 di Pulau Jawa, membantu SCM memprioritaskan rute logistik.</li>
            <li><strong>Efek Domino:</strong> Dengan integrasi, pabrik dapat melakukan
                <strong>pre-emptive capacity planning</strong>.</li>
        </ul>
    </div>
    """, unsafe_allow_html=True)

# Flow Arrow
st.markdown("""
<div class="flow-arrow">⬇️ DATA CRM MENGALIR KE ERP ⬇️</div>
""", unsafe_allow_html=True)

# ================================================================
# BAGIAN B — ERP
# ================================================================
st.markdown("""
<div class="section-title">
    <div class="dot" style="background: #f59e0b;"></div>
    <div>
        <h2>Bagian B: ERP — Enterprise Resource Planning</h2>
        <span class="label">Dapur Operasional &amp; Kapasitas Pabrik</span>
    </div>
</div>
""", unsafe_allow_html=True)

# KPI Row ERP
e1, e2, e3, e4 = st.columns(4)
e1.metric("Total Produksi", "85.000 Karton", "Lembur 3 Shift ▲")
e2.metric("OEE", "87.3%", "Mendekati Batas ⚠")
e3.metric("Stok Terendah", "4.000 Karton", "Safety Stock Terancam ▼")
e4.metric("Biaya Lembur/Hari", "Rp 2.8M", "+140% dari normal ▲")

# Chart + Insight
col_chart2, col_insight2 = st.columns([1.2, 1])

with col_chart2:
    fig_erp = go.Figure()

    # Bar — Target Produksi
    fig_erp.add_trace(go.Bar(
        x=erp_df["tanggal"],
        y=erp_df["target_produksi"],
        name="Target Produksi (Karton)",
        marker=dict(color="rgba(245,158,11,0.65)", line=dict(color="#f59e0b", width=2)),
        hovertemplate="Tanggal: %{x}<br>Target: %{y:,.0f} karton<extra></extra>"
    ))

    # Line — Sisa Stok
    fig_erp.add_trace(go.Scatter(
        x=erp_df["tanggal"],
        y=erp_df["sisa_stok"],
        mode="lines+markers",
        name="Sisa Stok Gudang (Karton)",
        line=dict(color="#ef4444", width=3, shape="spline"),
        marker=dict(size=10, color="#ef4444", line=dict(width=2, color="white")),
        fill="tozeroy",
        fillcolor="rgba(239,68,68,0.06)",
        hovertemplate="Tanggal: %{x}<br>Stok: %{y:,.0f} karton<extra></extra>"
    ))

    fig_erp.update_layout(
        title="🏭 Target Produksi vs Sisa Stok Gudang (Q1 2026)",
        xaxis_title="Tanggal",
        yaxis_title="Jumlah Karton",
        template="plotly_white",
        height=400,
        margin=dict(t=50, b=40),
        yaxis=dict(tickformat=","),
        barmode="overlay",
        legend=dict(orientation="h", yanchor="bottom", y=1.02, xanchor="right", x=1)
    )
    st.plotly_chart(fig_erp, use_container_width=True)

with col_insight2:
    st.markdown("""
    <div class="insight-box insight-erp">
        <strong>🔍 Insight Integrasi ERP</strong><br><br>
        Modul ERP menerima <em>demand signal</em> dari CRM dan merespons dengan meningkatkan
        target produksi. Data menunjukkan <strong>ketidakseimbangan kritis</strong>:
        <ul>
            <li><strong>Bottleneck 14 Februari:</strong> Saat target produksi mencapai 20.000 karton,
                stok gudang anjlok ke <strong>4.000 karton</strong> — hanya cukup 0.8 hari operasional.</li>
            <li><strong>Respons Kapasitas:</strong> ERP mengaktifkan <strong>Overtime Protocol</strong>
                (3 shift × 24 jam) dan men-trigger MRP untuk pengadaan bahan baku dari Bogasari.</li>
            <li><strong>Trigger ke SCM:</strong> Saat stok menyentuh <em>reorder point</em> (5.000),
                ERP mengirim <strong>Purchase Requisition (PR)</strong> ke SCM secara otomatis.</li>
            <li><strong>Pemulihan Maret:</strong> Stok naik ke 22.000 karton pada 12 Maret berkat
                koordinasi ERP↔SCM (<em>closed-loop</em>).</li>
        </ul>
    </div>
    """, unsafe_allow_html=True)

# Flow Arrow
st.markdown("""
<div class="flow-arrow">⬇️ ERP MENGIRIM PR KE SCM ⬇️</div>
""", unsafe_allow_html=True)

# ================================================================
# BAGIAN C — SCM
# ================================================================
st.markdown("""
<div class="section-title">
    <div class="dot" style="background: #10b981;"></div>
    <div>
        <h2>Bagian C: SCM — Supply Chain Management</h2>
        <span class="label">Tulang Punggung Logistik &amp; Pengadaan</span>
    </div>
</div>
""", unsafe_allow_html=True)

# KPI Row SCM
s1, s2, s3, s4 = st.columns(4)
s1.metric("Total Armada Aktif", "200 Unit", "+50 sewa ekstra ⚠")
s2.metric("On-Time Delivery", "97.5%", "Target Tercapai ✓")
s3.metric("Biaya Sewa Ekstra/Hari", "Rp 1.2M", "Biaya Darurat ▲")
s4.metric("Rute Distribusi", "14 Rute", "+4 rute baru ▲")

# Chart + Insight
col_chart3, col_insight3 = st.columns([1.2, 1])

with col_chart3:
    colors = ["#10b981", "#f97316"]
    fig_scm = go.Figure(data=[go.Pie(
        labels=scm_df["tipe"],
        values=scm_df["jumlah"],
        hole=0.55,
        marker=dict(colors=colors, line=dict(color="white", width=4)),
        textinfo="label+percent",
        textfont_size=13,
        hovertemplate="%{label}: %{value} unit (%{percent})<extra></extra>"
    )])
    fig_scm.update_layout(
        title="🚛 Komposisi Armada Logistik (Maret 2026)",
        template="plotly_white",
        height=420,
        margin=dict(t=50, b=40),
        annotations=[dict(
            text="<b>200</b><br><span style='font-size:12px;color:#64748b'>Total Armada</span>",
            x=0.5, y=0.5, font_size=24, showarrow=False
        )],
        legend=dict(orientation="h", yanchor="bottom", y=-0.15, xanchor="center", x=0.5)
    )
    st.plotly_chart(fig_scm, use_container_width=True)

with col_insight3:
    st.markdown("""
    <div class="insight-box insight-scm">
        <strong>🔍 Insight Integrasi SCM</strong><br><br>
        Modul SCM menjadi <strong>penyelamat terakhir</strong> dalam rantai integrasi CRM→ERP→SCM:
        <ul>
            <li><strong>Pengadaan Darurat:</strong> Ketika ERP mengirim PR karena stok menyentuh
                4.000 karton, SCM mengaktifkan kontrak <em>spot-buy</em> dengan <strong>50 truk
                sewa ekstra</strong> (25% total armada).</li>
            <li><strong>Closed-Loop Feedback:</strong> SCM mengirim balik <em>delivery confirmation</em>
                dan <em>lead time aktual</em> ke CRM, sehingga sales team memberi ETA akurat — meningkatkan
                customer satisfaction sebesar 12%.</li>
            <li><strong>Optimasi Biaya vs Risiko:</strong> Biaya sewa Rp 1.2M/hari vs potensi
                <em>lost sales</em> Rp 8.5M/hari — saving ratio <strong>7:1</strong>.</li>
            <li><strong>Bukti Integrasi:</strong> Seluruh siklus — dari CRM mendeteksi lonjakan,
                ERP merespons, hingga SCM mengeksekusi — terjadi dalam <strong>&lt;48 jam</strong>.
                Tanpa integrasi: 2–3 minggu.</li>
        </ul>
    </div>
    """, unsafe_allow_html=True)

# ================================================================
# KESIMPULAN
# ================================================================
st.markdown("""
<div class="summary-card">
    <h3>📋 Kesimpulan: Efek Domino Integrasi CRM → ERP → SCM</h3>
    <p>
        Studi kasus PT Indofood CBP membuktikan bahwa integrasi sistem <strong>CRM</strong>,
        <strong>ERP</strong>, dan <strong>SCM</strong> bukan sekadar konektivitas teknis, melainkan
        <strong>strategic enabler</strong> yang mengubah data menjadi keputusan bisnis real-time.
        Tanpa integrasi, setiap modul bekerja dalam silo. Dengan integrasi end-to-end,
        <strong>demand signal</strong> dari CRM langsung men-trigger <strong>production planning</strong>
        di ERP, yang kemudian mengaktifkan <strong>procurement &amp; logistics</strong> di SCM —
        menciptakan <strong>closed-loop supply chain</strong> yang responsif, efisien, dan mampu
        menghadapi volatilitas permintaan musiman seperti bulan Puasa.
    </p>
</div>
""", unsafe_allow_html=True)

# ================================================================
# DATA TABLE (Expandable)
# ================================================================
with st.expander("📋 Lihat Data Mentah (Raw Data)"):
    tab1, tab2, tab3 = st.tabs(["CRM — Pesanan", "ERP — Produksi & Stok", "SCM — Armada"])
    with tab1:
        st.dataframe(crm_df, use_container_width=True)
    with tab2:
        st.dataframe(erp_df, use_container_width=True)
    with tab3:
        st.dataframe(scm_df, use_container_width=True)

# Footer
st.markdown("---")
st.caption(
    "Dashboard dibuat untuk tugas mata kuliah **Sistem Informasi Manajemen** — Semester 3 | "
    "Studi Kasus: PT Indofood CBP Sukses Makmur Tbk. | Data bersifat simulasi untuk keperluan akademik. | "
    "© 2026 — Dibangun dengan Streamlit & Plotly"
)
