#!/usr/bin/env sh
set -eu

links_file="${1:-links.txt}"
output_file="${2:-nginx/default.conf}"

test -f "$links_file" || {
    echo "Links file not found: $links_file" >&2
    exit 1
}

mkdir -p "$(dirname "$output_file")"

cat > "$output_file" <<'EOF'
server {
    listen 80 default_server;
    server_name _;
    root /usr/share/nginx/html;
    index index.html;

    server_tokens off;
    add_header X-Content-Type-Options "nosniff" always;

    location = /version.txt {
        default_type text/plain;
        add_header Cache-Control "no-store, no-cache, must-revalidate, max-age=0" always;
        add_header Pragma "no-cache" always;
        add_header Expires "0" always;
        try_files /version.txt =404;
    }

    # This legacy Safari/Data Saver workaround is static HTML stored with a
    # .php extension. nginx serves it as text/html; PHP is never installed or
    # executed in this image.
    location = /enlace/congreso-dermapedia {
        default_type text/html;
        add_header Cache-Control "no-store, no-cache, must-revalidate, max-age=0" always;
        add_header Pragma "no-cache" always;
        add_header Expires "0" always;
        try_files /enlace/congreso-dermapedia/index.php =404;
    }

    location = /enlace/congreso-dermapedia/ {
        default_type text/html;
        add_header Cache-Control "no-store, no-cache, must-revalidate, max-age=0" always;
        add_header Pragma "no-cache" always;
        add_header Expires "0" always;
        try_files /enlace/congreso-dermapedia/index.php =404;
    }

    location = /enlace/congreso-dermapedia/index.php {
        default_type text/html;
        add_header Cache-Control "no-store, no-cache, must-revalidate, max-age=0" always;
        add_header Pragma "no-cache" always;
        add_header Expires "0" always;
        try_files /enlace/congreso-dermapedia/index.php =404;
    }

    location ~* \\.(?:php[0-9]?|phtml|phps)(?:$|/) {
        return 404;
    }
EOF

line_number=0
while IFS=' ' read -r path target extra; do
    line_number=$((line_number + 1))

    case "$path" in
        ''|'#'*) continue ;;
    esac

    if [ -n "${extra:-}" ] || [ -z "${target:-}" ]; then
        echo "Invalid links.txt entry on line $line_number: expected PATH URL" >&2
        exit 1
    fi

    case "$path" in
        /*) ;;
        *) echo "Invalid redirect path on line $line_number: $path" >&2; exit 1 ;;
    esac

    case "$path$target" in
        *'"'*|*'\\'*|*'$'*)
            echo "Unsupported character in links.txt on line $line_number" >&2
            exit 1
            ;;
    esac

    cat >> "$output_file" <<EOF

    location = "$path" {
        add_header Cache-Control "no-store, no-cache, must-revalidate, max-age=0" always;
        add_header Pragma "no-cache" always;
        add_header Expires "0" always;
        return 302 "$target";
    }
EOF

    case "$path" in
        */) ;;
        *)
            cat >> "$output_file" <<EOF

    location = "$path/" {
        add_header Cache-Control "no-store, no-cache, must-revalidate, max-age=0" always;
        add_header Pragma "no-cache" always;
        add_header Expires "0" always;
        return 302 "$target";
    }
EOF
            ;;
    esac
done < "$links_file"

cat >> "$output_file" <<'EOF'

    location / {
        try_files $uri $uri/ =404;
    }
}
EOF
