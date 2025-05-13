FROM nginx:latest

RUN apt update -y && apt install -y openssh-server

RUN mkdir -p /run/sshd
RUN echo 'PermitRootLogin yes' >> /etc/ssh/sshd_config
RUN echo 'PasswordAuthentication yes' >> /etc/ssh/sshd_config
RUN echo 'root:root' | chpasswd
RUN sed -i 's/#ListenAddress 0.0.0.0/ListenAddress 0.0.0.0/' /etc/ssh/sshd_config

RUN apt install -y --no-install-recommends openssh-client

RUN ssh-keygen -t rsa -N "" -f /root/.ssh/id_rsa
RUN cp /root/.ssh/id_rsa.pub /root/.ssh/authorized_keys
RUN chmod 400 /root/.ssh/authorized_keys
RUN chmod 600 /root/.ssh/id_rsa
RUN mkdir -p /ssh-key && cp /root/.ssh/id_rsa /ssh-key/id_rsa
RUN chmod -R 777 /ssh-key
RUN chown nobody:nogroup /ssh-key /ssh-key/id_rsa

# Cài đặt PHP và các module cần thiết
RUN apt update -y && apt install -y php-fpm php-cli php-common php-mysql php-gd php-curl php-mbstring php-xml php-zip \
    && rm -rf /var/lib/apt/lists/* # Dọn dẹp cache apt

# Xóa cấu hình Nginx mặc định
RUN rm /etc/nginx/conf.d/default.conf

# Sao chép cấu hình Nginx tùy chỉnh
COPY nginx/default.conf /etc/nginx/conf.d/default.conf 

# Cài đặt Docker Client
RUN apt update -y && apt install -y docker.io -y \
    && rm -rf /var/lib/apt/lists/* # Dọn dẹp cache apt

# Sao chép script khởi động và cấp quyền thực thi
COPY startup.sh /usr/local/bin/startup.sh
RUN chmod +x /usr/local/bin/startup.sh

EXPOSE 80
EXPOSE 22

# Sử dụng ENTRYPOINT để chạy script khởi động
ENTRYPOINT ["/usr/local/bin/startup.sh"]

CMD []