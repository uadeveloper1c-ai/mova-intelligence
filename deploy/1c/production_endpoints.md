# Производственные endpoints HTTP-сервиса `mova_api`

Все ресурсы находятся внутри существующего HTTP-сервиса `mova_api`.
Для каждого ресурса нужно создать HTTP-метод и назначить обработчик из модуля
HTTP-сервиса.

| Имя ресурса | Шаблон | Метод | Обработчик |
|---|---|---|---|
| `production_requests` | `/production/requests` | GET | `get_production_requests` |
| `production_warehouses` | `/production/warehouses` | GET | `get_production_warehouses` |
| `production_catalog` | `/production/catalog` | GET | `get_production_catalog` |
| `production_templates` | `/production/templates` | GET | `get_production_templates` |
| `production_templates_by_id` | `/production/templates/by-id` | GET | `get_production_templates_by_id` |
| `production_templates_create` | `/production/templates/create` | POST | `post_production_templates_create` |
| `production_templates_copy` | `/production/templates/copy` | POST | `post_production_templates_copy` |
| `production_templates_update` | `/production/templates/update` | POST | `post_production_templates_update` |
| `production_templates_archive` | `/production/templates/archive` | POST | `post_production_templates_archive` |
| `production_rules` | `/production/rules` | GET | `get_production_rules` |
| `production_requests_create` | `/production/requests/create` | POST | `post_production_requests_create` |
| `production_requests_create_from_template` | `/production/requests/create-from-template` | POST | `post_production_requests_create_from_template` |

## Проверка чтения

После публикации и заполнения данных проверить под пользователем с ролью
`Админ`:

```text
GET /hs/api/production/templates
GET /hs/api/production/templates/by-id?id=<UUID шаблона>
GET /hs/api/production/rules
GET /hs/api/production/catalog
GET /hs/api/production/catalog?q=<частина назви або коду>
GET /hs/api/production/warehouses
GET /hs/api/production/requests
```

Для фильтрации шаблонов по организации:

```text
GET /hs/api/production/templates?orgCode=<код организации>
```

`GET /production/catalog` возвращает первые 100 элементов номенклатуры.
Параметр `q` используется для поиска по наименованию или коду.

## Создание заказов из шаблона

```json
{
  "templateUid": "<UUID шаблона>",
  "subdivisionUid": "<UUID подразделения>",
  "volume": 4,
  "requiredDate": "2026-06-20",
  "comment": "Варка на пятницу"
}
```

`volume` пересчитывает строки относительно `БазовыйОбъем` шаблона. Например,
при базовом объёме `2` и запрошенном объёме `4` количества умножаются на `2`.

Для каждой уникальной `ГруппаЗаказа` состава создаётся отдельный
`ЗаказНаПеремещение`. Перед записью API ищет активное правило по комбинации:

```text
Организация + Подразделение + ВидШаблона + ГруппаЗаказа
```

Если хотя бы одно правило отсутствует или заполнено не полностью, транзакция
отменяется и ни один заказ не создаётся.

## Управление шаблонами

Создание и обновление используют единый JSON:

```json
{
  "uid": "<UUID только при обновлении>",
  "name": "Варка Lager 2 тонны",
  "organizationUid": "<UUID организации>",
  "templateType": "Сырье",
  "drinkType": "Пиво",
  "productUid": "<UUID готовой продукции>",
  "baseVolume": 2,
  "active": true,
  "comment": "",
  "lines": [
    {
      "group": "Зерно",
      "itemUid": "<UUID номенклатуры>",
      "packageUid": "<UUID упаковки или пустая строка>",
      "quantity": 100,
      "required": true,
      "comment": ""
    }
  ]
}
```

В `templateType`, `drinkType` и `group` передаются внутренние имена значений
перечислений 1С.

Копирование:

```json
{
  "templateUid": "<UUID исходного шаблона>",
  "name": "Новый шаблон"
}
```

Архивирование:

```json
{
  "uid": "<UUID шаблона>"
}
```

Архивирование устанавливает `Активен = Ложь`; физического удаления нет.

## Ограничения первого этапа

- доступ разрешён только роли мобильного приложения `Админ`;
- заказы записываются, но не проводятся;
- созданные заказы помечаются префиксом `[MOVA]` в комментарии;
- ручной `POST /production/requests/create` пока возвращает HTTP 501;
- дополнительные свойства `MOVA_*` в заказ ещё не записываются.
