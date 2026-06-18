# Mova Intelligence: продажи

Добавить ресурсы HTTP-сервиса `mova_api` для web-формы создания заказа клиента.

| Ресурс | Метод | Шаблон | Обработчик |
| --- | --- | --- | --- |
| `sales_partners` | GET | `/sales/partners` | `get_sales_partners` |
| `sales_agreements` | GET | `/sales/agreements` | `get_sales_agreements` |
| `sales_contracts` | GET | `/sales/contracts` | `get_sales_contracts` |
| `sales_catalog` | GET | `/sales/catalog` | `get_sales_catalog` |
| `sales_price_types` | GET | `/sales/price-types` | `get_sales_price_types` |
| `sales_price` | GET | `/sales/price` | `get_sales_price` |
| `sales_receivables` | GET | `/sales/receivables` | `get_sales_receivables` |
| `sales_customer_orders_create` | POST | `/sales/customer-orders/create` | `post_sales_customer_orders_create` |

Права: сейчас доступ ограничен ролью мобильного приложения `Админ`, чтобы запускать пилот без лишнего доступа для всех пользователей.

Параметры:
- `/sales/partners?q=...` ищет партнера.
- `/sales/catalog?q=...` ищет номенклатуру.
- `/sales/agreements?partnerUid=...` возвращает соглашения клиента.
- `/sales/contracts?partnerUid=...` возвращает договоры контрагента клиента.
- `/sales/price?itemUid=...&priceTypeUid=...` возвращает цену.
- `/sales/receivables?partnerUid=...` возвращает строки дебиторки, если в конфигурации совпал регистр взаиморасчетов.

Создание заказа:

```json
{
  "partnerUid": "...",
  "agreementUid": "...",
  "contractUid": "...",
  "shipmentDate": "2026-06-16T00:00:00.000",
  "comment": "",
  "lines": [
    {
      "itemUid": "...",
      "itemName": "Amber Ale",
      "quantity": 12,
      "priceTypeUid": "...",
      "price": 51,
      "manualPrice": false
    }
  ]
}
```
