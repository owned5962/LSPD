from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]


def test_store_npcs_and_interaction_do_not_depend_on_mysql_response():
    client = (ROOT / "resources/[FUNCTION]/rp_businesses/client/main.lua").read_text(encoding="utf-8")
    locations = (ROOT / "resources/[FUNCTION]/rp_businesses/shared/locations.lua").read_text(encoding="utf-8")

    assert "for _, category in ipairs(BusinessLocations or {}) do" in client
    assert "if category.id == 'food' then" in client
    assert "groceryPedModels" in client
    assert "IsModelInCdimage(candidate)" in client
    assert "CreatePed(4, model" in client
    assert "FreezeEntityPosition(ped, true)" in client
    assert "IsControlJustReleased(0, 38)" in client
    assert "rp_businesses:server:requestStore" in client
    assert "id = 'food'" in locations


def test_store_catalog_only_sells_registered_inventory_items():
    server = (ROOT / "resources/[FUNCTION]/rp_businesses/server/main.lua").read_text(encoding="utf-8")
    inventory = (ROOT / "resources/[FUNCTION]/rp_inventory/config.lua").read_text(encoding="utf-8")

    products_block = re.search(r"local STORE_PRODUCTS = \{(.*?)\n\}", server, re.S)
    assert products_block, "Store catalogue is missing"
    products = set(re.findall(r"([a-zA-Z0-9_]+)\s*=", products_block.group(1)))
    inventory_items = set(re.findall(r"\['([a-zA-Z0-9_]+)'\]\s*=", inventory))
    assert products
    assert products <= inventory_items


def test_store_checkout_validates_proximity_and_refunds_failed_inventory_add():
    server = (ROOT / "resources/[FUNCTION]/rp_businesses/server/main.lua").read_text(encoding="utf-8")
    assert "getStoreLocations()" in server
    assert server.count("getPlayerAtStore(src, 1.5)") == 2
    assert server.index("storePurchaseLocks[src] = true", server.index("buyStoreItem")) < server.index("pcall(player.removeCash, price)")
    assert "exports['rp_inventory']:AddItem(src, itemName, 1)" in server
    assert "pcall(player.addCash, price)" in server


def test_store_tablet_renders_product_image_price_and_buy_button():
    js = (ROOT / "resources/[FUNCTION]/rp_businesses/html/js/app.js").read_text(encoding="utf-8")
    html = (ROOT / "resources/[FUNCTION]/rp_businesses/html/index.html").read_text(encoding="utf-8")
    assert "makeProductImage" in js
    assert "data:image/svg+xml" in js
    assert "formatCash(product.price)" in js
    assert "button.textContent = 'ACHETER'" in js
    assert 'id="products"' in html
    assert "event.key === 'Escape'" in js


if __name__ == "__main__":
    test_store_npcs_and_interaction_do_not_depend_on_mysql_response()
    test_store_catalog_only_sells_registered_inventory_items()
    test_store_checkout_validates_proximity_and_refunds_failed_inventory_add()
    test_store_tablet_renders_product_image_price_and_buy_button()
    print("Store workflow checks passed.")
