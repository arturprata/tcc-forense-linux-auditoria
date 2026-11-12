SELECT u.username, h.command FROM users u CROSS JOIN shell_history h USING (uid);
