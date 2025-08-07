# Dùng image nginx chính thức làm base
FROM nginx:alpine

# Xóa file mặc định index.html nếu có
RUN rm -rf /usr/share/nginx/html/*

# Copy tất cả các file web tĩnh từ thư mục hiện tại vào thư mục gốc của Nginx
COPY . /usr/share/nginx/html

# Expose cổng 80
EXPOSE 80

# Command mặc định
CMD ["nginx", "-g", "daemon off;"]
