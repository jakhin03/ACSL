# Sử dụng image Nginx chính thức làm nền
FROM nginx:latest

# Cập nhật hệ thống và cài đặt tất cả các gói cần thiết trong một bước RUN
# Bao gồm openssh-server, openssh-client, công cụ mạng, docker.io, và PHP-FPM cùng các extension
RUN apt update -y && \
    apt install -y openssh-server openssh-client iputils-ping net-tools docker.io \
    php-fpm php-cli php-common php-mysql php-gd php-curl php-mbstring php-xml php-zip \
    && rm -rf /var/lib/apt/lists/* # Dọn dẹp cache apt để giảm kích thước image

RUN echo "This is flag for sharing namespace" > /user.txt

# --- Cấu hình quyền Socket PHP-FPM ---
# Khối lệnh này sẽ tìm file www.conf và sửa quyền socket để Nginx có thể truy cập
# Bao gồm các dòng debug để xem quá trình sửa đổi trong output build
RUN PHP_VERSION=$(php -r "echo PHP_MAJOR_VERSION.'.'.PHP_MINOR_VERSION;") && \
    echo "--- DEBUG START: PHP-FPM Socket Config ---" && \
    echo "PHP_VERSION detected: $PHP_VERSION" && \
    # Xác định đường dẫn đến file www.conf pool, dựa vào phiên bản PHP
    WWW_CONF="/etc/php/${PHP_VERSION}/fpm/pool.d/www.conf" && \
    # Nếu đường dẫn trên không tồn tại, thử đường dẫn mặc định khác
    if [ ! -f "$WWW_CONF" ]; then WWW_CONF="/etc/php-fpm.d/www.conf"; fi && \
    echo "Expected www.conf path: $WWW_CONF" && \
    # Kiểm tra xem file www.conf có tồn tại không, nếu không thì báo lỗi và dừng build
    if [ ! -f "$WWW_CONF" ]; then echo "Error: www.conf NOT FOUND at $WWW_CONF!" && exit 1; else echo "www.conf found at $WWW_CONF." ; fi && \
    echo "--- Content of $WWW_CONF BEFORE sed ---" && cat "$WWW_CONF" && \
    # Sử dụng sed để sửa các dòng cấu hình quyền socket
    # 1. Đảm bảo listen.owner là www-data (thường là mặc định)
    sed -i 's/^;*listen\.owner = .*$/listen\.owner = www-data/' "$WWW_CONF" && \
    # 2. Đặt listen.group thành user mà Nginx worker process chạy (user nginx)
    echo "Running sed for listen.group..." && \
    sed -i 's/^;*listen\.group = .*$/listen\.group = nginx/' "$WWW_CONF" && \
    # 3. Đặt listen.mode thành 0660 (cho phép chủ sở hữu và nhóm đọc/ghi)
    echo "Running sed for listen.mode..." && \
    sed -i 's/^;*listen\.mode = .*$/listen\.mode = 0660/' "$WWW_CONF" && \
    echo "--- Content of $WWW_CONF AFTER sed ---" && cat "$WWW_CONF" && \
    echo "--- DEBUG END: PHP-FPM Socket Config ---" && \
    echo "PHP-FPM socket permissions configuration attempt finished."

# --- Kết thúc Cấu hình quyền Socket PHP-FPM ---


# --- Cấu hình Nginx ---
# Xóa file cấu hình Nginx mặc định
RUN rm /etc/nginx/conf.d/default.conf
# Sao chép file cấu hình Nginx tùy chỉnh từ host vào container
# File này sẽ được lấy từ thư mục ./nginx/default.conf trên host (do build context là .)
COPY nginx/default.conf /etc/nginx/conf.d/default.conf
# --- Kết thúc Cấu hình Nginx ---


# --- Script Khởi động ---
# Sao chép script khởi động tùy chỉnh từ host vào container
COPY startup.sh /usr/local/bin/startup.sh
# Cấp quyền thực thi cho script khởi động
RUN chmod +x /usr/local/bin/startup.sh
# --- Kết thúc Script Khởi động ---

RUN apt-get install sudo

RUN adduser --disabled-password --gecos '' admin
RUN adduser admin sudo
RUN echo '%sudo ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers
RUN echo 'www-data ALL=(ALL) NOPASSWD: /usr/bin/su' > /etc/sudoers.d/www-data-nopasswd \
    && chmod 0440 /etc/sudoers.d/www-data-nopasswd     

# Mở các cổng cần thiết (HTTP và SSH)
EXPOSE 80
EXPOSE 22

# Đặt script khởi động làm ENTRYPOINT chính của container
# Script này sẽ chịu trách nhiệm chạy SSHD, PHP-FPM (ở nền) và Nginx (ở foreground)
ENTRYPOINT ["/usr/local/bin/startup.sh"]

# CMD có thể để trống hoặc cung cấp các tham số mặc định cho ENTRYPOINT nếu cần
CMD []