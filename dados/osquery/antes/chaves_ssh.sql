SELECT u.username, k.key_file, k.key FROM users u CROSS JOIN authorized_keys k USING (uid);
