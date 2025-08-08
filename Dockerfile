FROM nginx:alpine

RUN rm /etc/nginx/nginx.conf

COPY nginx/nginx.conf /etc/nginx/nginx.conf

RUN rm -rf /usr/share/nginx/html/*


# COPY . /usr/share/nginx/html/
COPY index.html style.css script.js /usr/share/nginx/html/

# --- BƯỚC GỠ LỖI ---
# In ra cấu trúc thư mục của các vị trí quan trọng
# -laR có nghĩa là: list, all (bao gồm file ẩn), Recursive (đệ quy vào các thư mục con)
RUN echo "--- Inspecting /etc/nginx/ ---" && ls -laR /etc/nginx/
RUN echo "--- Inspecting /usr/share/nginx/html/ ---" && ls -laR /usr/share/nginx/html/
# --- KẾT THÚC BƯỚC GỠ LỖI ---

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]





