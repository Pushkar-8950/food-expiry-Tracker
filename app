import streamlit as st
from database import create_table, add_item, get_items, delete_item
from reminder import check_expiry
import pytesseract
from PIL import Image
import re
from datetime import datetime

# Configure Tesseract path
pytesseract.pytesseract.tesseract_cmd = r"C:\Program Files\Tesseract-OCR\tesseract.exe"

# Streamlit page setup
st.set_page_config(page_title="Food Expiry Tracker", layout="wide")
st.title("🥫 Food Expiry Tracker")

# Ensure database is ready
create_table()

# Tabs for different sections
tab1, tab2, tab3, tab4 = st.tabs(["➕ Add Item", "📋 View Items", "⚠️ Check Expiry", "🗑️ Delete Item"])

# ---------------- ADD ITEM ----------------
with tab1:
    st.header("Add Food Item")

    add_method = st.radio("Select Method", ["Manual Entry", "Extract from Image (OCR)"])

    # Manual entry
    if add_method == "Manual Entry":
        name = st.text_input("Food Name")
        quantity = st.number_input("Quantity", min_value=1, step=1)
        expiry_date = st.date_input("Expiry Date")

        if st.button("Add Item"):
            add_item(name, quantity, expiry_date.strftime("%Y-%m-%d"))
            st.success(f"Added {name} successfully!")

    # OCR-based entry
    else:
        uploaded_image = st.file_uploader("Upload image", type=["jpg", "jpeg", "png", "webp"])
        if uploaded_image:
            img = Image.open(uploaded_image)
            st.image(img, caption="Uploaded Image", use_container_width=True)

            # OCR text extraction
            text = pytesseract.image_to_string(img)
            st.text_area("Extracted Text", text, height=150)

            # Try to detect expiry date automatically
            expiry_match = re.search(
                r'(Exp\.?|Expiry|Best\s*Before)[^\d]*(\d{1,2}\s*[A-Za-z]{3,}\s*\d{4})',
                text, re.IGNORECASE
            )

            detected_date = None
            if expiry_match:
                raw_date = expiry_match.group(2).strip()
                for fmt in ("%d %b %Y", "%d %B %Y"):
                    try:
                        detected_date = datetime.strptime(raw_date, fmt).strftime("%Y-%m-%d")
                        break
                    except ValueError:
                        continue
                if detected_date:
                    st.info(f"Detected expiry date: {detected_date}")

            # User input
            name = st.text_input("Food Name (edit if needed)")
            quantity = st.number_input("Quantity", min_value=1, step=1)
            expiry_date = st.text_input("Expiry Date (YYYY-MM-DD)", detected_date or "")

            if st.button("Save Item"):
                if not name or not expiry_date:
                    st.warning("Please fill all fields.")
                else:
                    add_item(name, quantity, expiry_date)
                    st.success(f"Added {name} successfully!")

# ---------------- VIEW ITEMS ----------------
with tab2:
    st.header("Tracked Items")
    items = get_items()
    if not items:
        st.info("No items found.")
    else:
        for item in items:
            st.write(f"**{item[1]}** — Quantity: {item[2]}, Expires on: {item[3]}")

# ---------------- CHECK EXPIRY ----------------
with tab3:
    st.header("Expiry Check")
    expired, expiring_soon = check_expiry()

    if not expired and not expiring_soon:
        st.info("No items are expired or near expiry.")
    else:
        if expired:
            st.error("❌ Expired Items:")
            for item in expired:
                st.write(f"{item[1]} (x{item[2]}) — expired on {item[3]}")

        if expiring_soon:
            st.warning("⚠️ Expiring Soon (within 7 days):")
            for item in expiring_soon:
                st.write(f"{item[1]} (x{item[2]}) — expires on {item[3]}")

# ---------------- DELETE ITEM ----------------
with tab4:
    st.header("Delete Item")
    items = get_items()
    if not items:
        st.info("No items available to delete.")
    else:
        item_options = {f"{i[1]} (expires {i[3]})": i[0] for i in items}
        selected_item = st.selectbox("Select item to delete", list(item_options.keys()))
        if st.button("Delete"):
            delete_item(item_options[selected_item])
            st.success("Item deleted.")
