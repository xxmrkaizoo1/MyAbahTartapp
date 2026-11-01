"""Copies the website's customers and sales into the app's Firebase (a one-time copy).

What it copies from the Laravel database (MySQL `myabahtartlejen`):
  - customers  -> users/web-<id>        (name, email, phone, address; never passwords)
  - orders     -> orders/<code>         (online and counter sales, with their items)
  - refunds    -> refunds/web-<id>
  - reviews    -> products/<slug>/reviews/web-<user id>
Every copied document has fromWebsite: true. Orders the app created itself are never overwritten.
When a customer signs up in the app with the same email and verifies it, the app moves
their website orders and refunds onto their new account.

Run from the project folder, with Laragon's MySQL started and `firebase login` done:
  python tool/import_website_data.py            # preview: shows what would be copied
  python tool/import_website_data.py --write    # copies it into Firebase
"""
import datetime
import glob
import json
import os
import re
import shutil
import subprocess
import sys
import urllib.error
import urllib.request

PROJECT = 'myabahtartlejen'
DATABASE = 'myabahtartlejen'
BASE = f'https://firestore.googleapis.com/v1/projects/{PROJECT}/databases/(default)/documents'
WEBSITE_TZ = datetime.timezone(datetime.timedelta(hours=8))  # APP_TIMEZONE=Asia/Kuala_Lumpur

# Website upload file -> photo bundled in the app (assets/images).
PHOTOS = {
    'products/rZcufNkc6zKLksFXj1M0kx2qT5tzNQJzTnj6wnC6.png': 'products/tart-lejen.jpg',
    'products/mdIgOvylO4fuXutntfmNIONQXnr1U8ti5B7IwHAI.png': 'products/tart-lejen-s.jpg',
    'products/6t6lHArRzRXkZgya4VU7YgbPz4mRo3K1kxKOuV1p.png': 'products/tart-lejen-m.jpg',
    'products/PivjoTkUVyxPaZ0baTLsI5VKeByvmYnXvyJ4nRf6.png': 'products/tart-lejen-l.jpg',
    'products/N5jB1eSuxiJ7IRKc9FRr9KTdJcdUZi25YqVECxNg.png': 'products/rempeyek-kacang-bilis.jpg',
    'products/DFFRG0oluG6pqCYpXhn6Gq5gskogJZ62miHeIB01.png': 'products/rempeyek-kacang-dal.jpg',
    'products/QFrob7XAemYfwwAXtbxyfWJtjAEwtbckxlNLCjwF.png': 'products/kerepek-pisang-peket.jpg',
    'products/EIh9ypilxsext2PBetg05uvir5NKhGNQZA2eFhIb.png': 'products/kerepek-pisang-balang.jpg',
    'products/NrdkN476G3dAuuKxpiOSCyWDdSqCxqkPoPGAdY7V.png': 'products/kerepek-bawang.jpg',
    'products/ZC9hRm06p4simv1PAh4ouExfsDHXtCeTqrEO6xtt.png': 'products/keropok-ikan-pedas.jpg',
    'products/fCjMok5snkXXGtdNtRdwM1Bd74BSvkQoFC3UP8nJ.png': 'products/keropok-ikan.jpg',
}

QUERY = """
select json_object(
  'users', (select json_arrayagg(json_object('id', id, 'name', name, 'email', email, 'phone', phone, 'address', address,
            'role', role, 'created_at', created_at)) from users),
  'products', (select json_arrayagg(json_object('id', id, 'slug', slug, 'art', art, 'image_path', image_path,
            'size_images', size_images)) from products),
  'orders', (select json_arrayagg(json_object('id', id, 'code', code, 'user_id', user_id, 'customer_name', customer_name,
            'status', status, 'channel', channel, 'delivery_method', delivery_method, 'phone', phone, 'address', address,
            'notes', notes, 'subtotal', subtotal, 'delivery_fee', delivery_fee, 'discount', discount, 'total', total,
            'payment_method', payment_method, 'amount_tendered', amount_tendered, 'payment_status', payment_status,
            'served_by', served_by, 'voucher_code', voucher_code, 'preparing_at', preparing_at, 'ready_at', ready_at,
            'completed_at', completed_at, 'cancelled_at', cancelled_at, 'cancellation_reason', cancellation_reason,
            'cancellation_note', cancellation_note, 'created_at', created_at)) from orders),
  'order_items', (select json_arrayagg(json_object('id', id, 'order_id', order_id, 'product_id', product_id,
            'product_name', product_name, 'size', size, 'unit_price', unit_price, 'quantity', quantity,
            'line_total', line_total)) from order_items),
  'refunds', (select json_arrayagg(json_object('id', id, 'order_id', order_id, 'processed_by', processed_by,
            'status', status, 'reason', reason, 'details', details, 'amount', amount, 'method', method,
            'restocked', restocked, 'admin_note', admin_note, 'processed_at', processed_at, 'created_at', created_at))
            from refunds),
  'refund_items', (select json_arrayagg(json_object('refund_id', refund_id, 'order_item_id', order_item_id,
            'quantity', quantity)) from refund_items),
  'reviews', (select json_arrayagg(json_object('product_id', product_id, 'user_id', user_id, 'rating', rating,
            'comment', comment, 'created_at', created_at)) from reviews)
)
"""


def fail(message):
    sys.exit(f'\n{message}\n')


# ------------------------------------------------------------------ Reading the website database

def read_website():
    candidates = sorted(glob.glob(r'C:\laragon\bin\mysql\*\bin\mysql.exe'), reverse=True)
    mysql = shutil.which('mysql') or (candidates[0] if candidates else None)
    if not mysql:
        fail('Could not find mysql.exe. Is Laragon installed in C:\\laragon?')
    result = subprocess.run([mysql, '-uroot', '-h127.0.0.1', '--default-character-set=utf8mb4', '-N', '-r', '-B', DATABASE, '-e', QUERY],
                            capture_output=True, text=True, encoding='utf-8')
    if result.returncode != 0:
        fail(f'Could not read the website database. Start MySQL in Laragon ("Start All") and try again.\n{result.stderr.strip()}')
    data = json.loads(result.stdout)
    return {key: value or [] for key, value in data.items()}


def when(value):
    """Website times are Malaysia time; Firestore wants UTC."""
    if not value:
        return None
    moment = datetime.datetime.fromisoformat(str(value)[:19]).replace(tzinfo=WEBSITE_TZ)
    return moment.astimezone(datetime.timezone.utc)


def money(value):
    return None if value is None else round(float(value), 2)


def photo(path):
    return 'asset:assets/images/' + PHOTOS[path] if path in PHOTOS else None


def parse(value):
    return json.loads(value) if isinstance(value, str) else value


def slugify(text):
    return re.sub(r'(^-|-$)', '', re.sub(r'[^a-z0-9]+', '-', text.lower()))


def build(web):
    users = {u['id']: u for u in web['users']}
    products = {p['id']: p for p in web['products']}
    items_by_order = {}
    for item in sorted(web['order_items'], key=lambda item: item['id']):
        items_by_order.setdefault(item['order_id'], []).append(item)
    orders_by_id = {o['id']: o for o in web['orders']}

    def email_of(user_id):
        return (users.get(user_id) or {}).get('email', '').strip().lower()

    def name_of(user_id):
        return (users.get(user_id) or {}).get('name')

    customers = {
        f"web-{u['id']}": {
            'name': u['name'],
            'email': u['email'].strip().lower(),
            'phone': u['phone'],
            'address': u['address'],
            'role': 'customer',
            'fromWebsite': True,
            'createdAt': when(u['created_at']),
        }
        for u in web['users'] if u['role'] != 'admin'
    }

    refunded = {}
    for refund in web['refunds']:
        if refund['status'] == 'approved':
            refunded[refund['order_id']] = refunded.get(refund['order_id'], 0) + float(refund['amount'] or 0)

    orders = {}
    for o in web['orders']:
        items = []
        for item in items_by_order.get(o['id'], []):
            product = products.get(item['product_id']) or {}
            size_images = parse(product.get('size_images')) or {}
            items.append({
                'productId': product.get('slug') or slugify(item['product_name']),
                'name': item['product_name'],
                'size': item['size'],
                'unitPrice': money(item['unit_price']),
                'quantity': item['quantity'],
                'lineTotal': money(item['line_total']),
                'art': product.get('art') or 'pineapple',
                'imageUrl': photo(size_images.get(item['size'])) or photo(product.get('image_path')),
            })
        online = o['channel'] == 'online'
        orders[o['code']] = {
            'userId': f"web-{o['user_id']}" if o['user_id'] and online else '',
            'customerName': o['customer_name'] or name_of(o['user_id']) or ('Customer' if online else 'Walk-in customer'),
            'email': email_of(o['user_id']) if online else '',
            'status': o['status'],
            'channel': o['channel'],
            'deliveryMethod': o['delivery_method'],
            'phone': o['phone'] or '',
            'address': o['address'],
            'notes': o['notes'],
            'items': items,
            'productIds': sorted({item['productId'] for item in items}),
            'subtotal': money(o['subtotal']),
            'deliveryFee': money(o['delivery_fee']),
            'discount': money(o['discount']),
            'total': money(o['total']),
            'voucherCode': o['voucher_code'],
            'paymentMethod': o['payment_method'] or 'cash',
            'paymentStatus': o['payment_status'] or ('unpaid' if online else 'paid'),
            'amountTendered': money(o['amount_tendered']),
            'servedBy': name_of(o['served_by']),
            'refundedAmount': round(refunded.get(o['id'], 0), 2),
            'createdAt': when(o['created_at']),
            'preparingAt': when(o['preparing_at']),
            'readyAt': when(o['ready_at']),
            'completedAt': when(o['completed_at']),
            'cancelledAt': when(o['cancelled_at']),
            'cancellationReason': o['cancellation_reason'] or None,
            'cancellationNote': o['cancellation_note'],
            'fromWebsite': True,
        }

    refund_items = {}
    for item in web['refund_items']:
        refund_items.setdefault(item['refund_id'], []).append(item)
    refunds = {}
    for r in web['refunds']:
        order = orders_by_id.get(r['order_id'])
        if not order:
            continue
        lines = items_by_order.get(order['id'], [])
        index_of = {line['id']: index for index, line in enumerate(lines)}
        refunds[f"web-{r['id']}"] = {
            'orderCode': order['code'],
            'userId': orders[order['code']]['userId'],
            'customerName': orders[order['code']]['customerName'],
            'email': orders[order['code']]['email'],
            'status': r['status'],
            'reason': r['reason'],
            'details': r['details'],
            'items': [
                {
                    'index': index_of[item['order_item_id']],
                    'name': lines[index_of[item['order_item_id']]]['product_name'],
                    'size': lines[index_of[item['order_item_id']]]['size'],
                    'quantity': item['quantity'],
                    'unitPrice': money(lines[index_of[item['order_item_id']]]['unit_price']),
                }
                for item in refund_items.get(r['id'], []) if item['order_item_id'] in index_of
            ],
            'amount': money(r['amount']) or 0.0,
            'method': r['method'],
            'restocked': bool(r['restocked']),
            'adminNote': r['admin_note'],
            'processedBy': name_of(r['processed_by']),
            'createdAt': when(r['created_at']),
            'processedAt': when(r['processed_at']),
            'fromWebsite': True,
        }

    reviews = {}
    for review in web['reviews']:
        product = products.get(review['product_id'])
        if not product:
            continue
        reviews[f"products/{product['slug']}/reviews/web-{review['user_id']}"] = {
            'userName': name_of(review['user_id']) or 'Customer',
            'rating': review['rating'],
            'comment': review['comment'] or '',
            'createdAt': when(review['created_at']),
            'fromWebsite': True,
        }

    return customers, orders, refunds, reviews


# ------------------------------------------------------------------ Writing to Firestore

def access_token():
    firebase = shutil.which('firebase.cmd') or shutil.which('firebase')
    if not firebase:
        fail('The Firebase CLI is not installed. Install it with: npm install -g firebase-tools')
    # Any CLI call refreshes the saved login if it has expired.
    check = subprocess.run([firebase, 'projects:list', '--json'], capture_output=True, text=True, encoding='utf-8')
    if check.returncode != 0:
        fail('Not logged in to Firebase. Run: firebase login')
    config = os.path.join(os.path.expanduser('~'), '.config', 'configstore', 'firebase-tools.json')
    return json.load(open(config, encoding='utf-8'))['tokens']['access_token']


def encode(value):
    if value is None:
        return {'nullValue': None}
    if isinstance(value, bool):
        return {'booleanValue': value}
    if isinstance(value, int):
        return {'integerValue': str(value)}
    if isinstance(value, float):
        return {'doubleValue': value}
    if isinstance(value, datetime.datetime):
        return {'timestampValue': value.strftime('%Y-%m-%dT%H:%M:%SZ')}
    if isinstance(value, str):
        return {'stringValue': value}
    if isinstance(value, dict):
        return {'mapValue': {'fields': {k: encode(v) for k, v in value.items()}}}
    if isinstance(value, list):
        return {'arrayValue': {'values': [encode(v) for v in value]}}
    raise TypeError(value)


def request(token, method, url, body=None):
    data = json.dumps(body).encode() if body is not None else None
    req = urllib.request.Request(url, data=data, method=method, headers={'Authorization': f'Bearer {token}', 'Content-Type': 'application/json'})
    try:
        return json.load(urllib.request.urlopen(req))
    except urllib.error.HTTPError as error:
        fail(f'Firebase refused the request ({error.code}): {error.read().decode()[:400]}')


def app_made_orders(token):
    """Codes of orders the app created itself, which must not be overwritten."""
    codes, page = set(), ''
    while True:
        url = f'{BASE}/orders?pageSize=300&mask.fieldPaths=fromWebsite' + (f'&pageToken={page}' if page else '')
        result = request(token, 'GET', url)
        for doc in result.get('documents', []):
            if not doc.get('fields', {}).get('fromWebsite', {}).get('booleanValue'):
                codes.add(doc['name'].rsplit('/', 1)[1])
        page = result.get('nextPageToken')
        if not page:
            return codes


def write(token, documents):
    writes = [{'update': {'name': f'projects/{PROJECT}/databases/(default)/documents/{path}', 'fields': {k: encode(v) for k, v in fields.items()}}}
              for path, fields in documents]
    for start in range(0, len(writes), 400):
        request(token, 'POST', f'{BASE}:commit', {'writes': writes[start:start + 400]})


def main():
    web = read_website()
    customers, orders, refunds, reviews = build(web)
    sales = sum(order['total'] for order in orders.values() if order['status'] == 'completed')

    print(f'From the website database:')
    print(f'  {len(customers)} customers (no passwords)')
    print(f'  {len(orders)} orders ({sum(o["channel"] == "online" for o in orders.values())} online, '
          f'{sum(o["channel"] == "counter" for o in orders.values())} counter), RM {sales:,.2f} in completed sales')
    print(f'  {len(refunds)} refunds, {len(reviews)} reviews')

    if '--write' not in sys.argv:
        print('\nPreview only. Run again with --write to copy this into Firebase.')
        return

    token = access_token()
    skipped = app_made_orders(token) & set(orders)
    for code in skipped:
        del orders[code]
    documents = ([(f'users/{key}', doc) for key, doc in customers.items()]
                 + [(f'orders/{code}', doc) for code, doc in orders.items()]
                 + [(f'refunds/{key}', doc) for key, doc in refunds.items()]
                 + list(reviews.items()))
    write(token, documents)
    print(f'\nCopied {len(documents)} documents into Firebase project "{PROJECT}".')
    if skipped:
        print(f'Left {len(skipped)} app orders with the same code untouched: {", ".join(sorted(skipped))}')


if __name__ == '__main__':
    main()
