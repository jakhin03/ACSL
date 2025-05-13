#!/bin/bash

# Script khởi động cho service victim (Nginx, PHP-FPM, SSH)

echo "--- Running startup.sh ---" >&2

# Khởi động dịch vụ SSH trong nền
# Chạy sshd trực tiếp là cách chuẩn trong môi trường Docker
echo "Starting SSH daemon..." >&2
/usr/sbin/sshd >&2 &

# Khởi động dịch vụ PHP-FPM trong nền
echo "Finding php-fpm executable..." >&2
# Tìm đường dẫn file thực thi php-fpm (thường là /usr/sbin/php-fpmX.Y)
# Sử dụng command -v trước (nếu nó có trong PATH), rồi tìm kiếm
PHP_FPM_EXEC=$(command -v php-fpm || find /usr/sbin/ /usr/local/sbin/ -name 'php-fpm*' -perm +111 -print -quit)

if [ -z "$PHP_FPM_EXEC" ]; then
    echo "Error: php-fpm executable not found!" >&2
    echo "PHP-FPM will not be started." >&2
    # Quyết định có thoát container nếu không tìm thấy php-fpm không
    # exit 1
else
    echo "Starting PHP-FPM using $PHP_FPM_EXEC" >&2
    # Chạy php-fpm ở foreground (-F) và đưa vào nền (&)
    # Output của php-fpm (ở chế độ -F) sẽ được docker logs thu thập
    "$PHP_FPM_EXEC" -F >&2 &
    echo "PHP-FPM started (hopefully)." >&2
    # Đợi một chút để PHP-FPM kịp khởi động và tạo socket
    sleep 1
fi

# Khởi động Nginx ở foreground
# Lệnh exec sẽ thay thế tiến trình script bằng tiến trình Nginx,
# đảm bảo Nginx là tiến trình chính của container.
echo "Starting Nginx in foreground..." >&2
exec nginx -g "daemon off;"