# Discourse Etiquette plugin
This plugin flags toxic post by Google's Perspective API.

## Installation

Follow the directions at [Install a Plugin](https://meta.discourse.org/t/install-a-plugin/19157) using https://github.com/fantasticfears/discourse-etiquette.git as the repository URL.

## Authors

Erick Guan

## License

GNU GPL v2

## Data Explorer Queries

If you choose standard mode, use `post_etiquette_toxicity`. Otherwise, replace them to `post_etiquette_severe_toxicity`. For most toxic categories and users, I choose a
probability 0.85 as the threshold.

Most toxic categories:

```sql
SELECT COUNT(pc) as counts, c.id, c.name, c.description
FROM post_custom_fields pc
JOIN posts p ON p.id = pc.post_id
JOIN topics t ON t.id = p.topic_id
JOIN categories c ON c.id = t.category_id
WHERE pc.name = 'post_etiquette_toxicity' AND pc.value >= '0.85'
GROUP BY c.id
ORDER BY counts DESC
LIMIT 100
```

Most toxic users:

```sql
SELECT COUNT(pc) as counts, u.id, u.username, u.trust_level, u.suspended_till, u.silenced_till
FROM post_custom_fields pc
JOIN posts p ON p.id = pc.post_id
JOIN users u ON p.user_id = u.id
WHERE pc.name = 'post_etiquette_toxicity' AND pc.value >= '0.85'
GROUP BY u.id
ORDER BY counts DESC
LIMIT 100
```

Most toxic posts:

```sql
SELECT p.id, pc.value, p.user_id, p.topic_id, p.created_at, p.raw
FROM post_custom_fields pc
JOIN posts p ON p.id = pc.post_id
WHERE pc.name = 'post_etiquette_toxicity'
ORDER BY pc.value DESC
LIMIT 100
```

Most toxic posts today:

```sql
SELECT p.id, pc.value, p.user_id, p.topic_id, p.created_at, p.raw
FROM post_custom_fields pc
JOIN posts p ON p.id = pc.post_id
WHERE pc.name = 'post_etiquette_toxicity' AND
p.created_at >= CURRENT_DATE
ORDER BY pc.value DESC
LIMIT 100
```
