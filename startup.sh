#!/bin/bash

# Script khởi động cho service victim (Nginx, PHP-FPM, SSH)

echo "--- Running startup.sh ---" >&2 # Ghi log script ra stderr

# Khởi động dịch vụ SSH trong nền
# Chạy sshd trực tiếp là cách chuẩn trong môi trường Docker
echo "Starting SSH daemon..." >&2
/usr/sbin/sshd >&2 &

# Khởi động dịch vụ PHP-FPM trong nền
echo "Finding php-fpm executable..." >&2
PHP_FPM_EXEC=""

# --- Bắt đầu phương pháp tìm kiếm file thực thi PHP-FPM đáng tin cậy hơn ---

# Thử các đường dẫn mặc định phổ biến dựa trên phiên bản PHP
# Lấy phiên bản PHP (ví dụ: 7.4)
PHP_VERSION=$(php -v 2>/dev/null | grep 'PHP' | awk '{print $2}' | cut -d'.' -f1,2)

if [ -n "$PHP_VERSION" ]; then
    # Thử các đường dẫn có chứa phiên bản
    if [ -x "/usr/sbin/php-fpm${PHP_VERSION}" ]; then
        PHP_FPM_EXEC="/usr/sbin/php-fpm${PHP_VERSION}"
    elif [ -x "/usr/bin/php-fpm${PHP_VERSION}" ]; then
        PHP_FPM_EXEC="/usr/bin/php-fpm${PHP_VERSION}"
    fi
fi

# Nếu vẫn chưa tìm thấy, thử các đường dẫn không có phiên bản
if [ -z "$PHP_FPM_EXEC" ]; then
     if [ -x "/usr/sbin/php-fpm" ]; then
         PHP_FPM_EXEC="/usr/sbin/php-fpm"
     elif [ -x "/usr/bin/php-fpm" ]; then
         PHP_FPM_EXEC="/usr/bin/php-fpm"
     fi
fi

# Phương pháp cuối cùng: Sử dụng find đơn giản hơn nếu các cách trên thất bại
# Bỏ tùy chọn '-perm +111' gây lỗi
if [ -z "$PHP_FPM_EXEC" ]; then
    echo "Standard paths failed, trying simple find..." >&2
    # Tìm file có tên 'php-fpm*' trong các thư mục bin/sbin phổ biến
    FOUND_PATH=$(find /usr/sbin/ /usr/bin/ /usr/local/sbin/ /usr/local/bin/ -name 'php-fpm*' -print -quit)
    # Kiểm tra lại xem file tìm được có quyền thực thi không (-x)
    if [ -n "$FOUND_PATH" ] && [ -x "$FOUND_PATH" ]; then
         PHP_FPM_EXEC="$FOUND_PATH"
    fi
fi

# --- Kết thúc phương pháp tìm kiếm ---


if [ -z "$PHP_FPM_EXEC" ]; then
    echo "Error: php-fpm executable not found or not executable after trying all methods!" >&2
    echo "PHP-FPM will not be started." >&2
    # Tùy chọn: nếu PHP là bắt buộc, uncomment dòng exit dưới đây để container dừng lại và báo lỗi
    # exit 1 # Nếu PHP là bắt buộc cho lab này
else
    echo "Found php-fpm executable: $PHP_FPM_EXEC" >&2
    # Chạy php-fpm ở foreground (-F) và đưa vào nền (&)
    # Output của php-fpm (ở chế độ -F) sẽ được docker logs thu thập
    echo "Starting PHP-FPM with command: \"$PHP_FPM_EXEC\" -F" >&2
    "$PHP_FPM_EXEC" -F >&2 &

    # Đợi một chút để PHP-FPM kịp khởi động và tạo socket (nếu dùng socket)
    sleep 1
    echo "PHP-FPM started (hopefully)." >&2

    # Tùy chọn: Chờ socket sẵn sàng trước khi khởi động Nginx
    # Điều này cần thêm công cụ như 'wait-for-it.sh' hoặc script kiểm tra socket
    # Đối với lab, sleep 1 có thể đủ, hoặc bỏ qua nếu không cần độ tin cậy cao nhất
fi

# Khởi động Nginx ở foreground
# Lệnh exec sẽ thay thế tiến trình script bằng tiến trình Nginx,
# đảm bảo Nginx là tiến trình chính của container.
echo "Starting Nginx in foreground..." >&2
exec nginx -g "daemon off;"