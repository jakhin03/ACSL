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
RUN chmod 777 /ssh-key
RUN chown nobody:nogroup /ssh-key /ssh-key/id_rsa

EXPOSE 80
EXPOSE 22

CMD ["nginx", "-g", "daemon off;"]