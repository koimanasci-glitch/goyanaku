# Deploy GOYANA

GOYANA (Laravel + database + dashboard web + aplikasi web `/app/`) **tidak butuh Node.js**. WhatsApp ada di server CHATKU sendiri (§41).
Jadi GOYANA bisa jalan di **VPS** maupun **hosting cPanel (Jagoan Hosting)** yang mendukung PHP 8.3, MySQL, SSH/Terminal, dan Cron.

Kebutuhan:
- PHP 8.3+ dengan ekstensi: mbstring, xml, curl, zip, intl, pdo_mysql, bcmath
- MySQL 8 / MariaDB 10.6+
- Composer
- HTTPS
- Python 3 (hanya untuk membangun `/app/`)

## A. VPS (Ubuntu 24.04), saran 2 GB RAM / 40 GB+ SSD

```bash
sudo apt update && sudo apt install -y nginx mysql-server php8.3-fpm php8.3-{mysql,mbstring,xml,curl,zip,intl,bcmath} composer git python3 certbot python3-certbot-nginx unzip
sudo mysql -e "CREATE DATABASE goyana CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci; CREATE USER 'goyana'@'localhost' IDENTIFIED BY 'GANTI_PASSWORD_KUAT'; GRANT ALL ON goyana.* TO 'goyana'@'localhost';"
sudo mkdir -p /var/www && cd /var/www && sudo git clone https://github.com/rajabadutiklan-lab/Goyana.git goyana && sudo chown -R $USER:www-data goyana
cd goyana/backend && cp .env.example .env && composer install --no-dev --optimize-autoloader && php artisan key:generate
nano .env   # isi bagian "Isi .env produksi" di bawah
php artisan migrate --force
php artisan goyana:admin          # buat akun admin pusat (OTP wajib saat login pertama)
sudo chown -R www-data:www-data storage bootstrap/cache
cd .. && bash deploy/build-web-app.sh https://DOMAIN
sudo cp deploy/nginx-goyana.conf /etc/nginx/sites-available/goyana   # ganti DOMAIN di file
sudo ln -s ../sites-available/goyana /etc/nginx/sites-enabled/ && sudo nginx -t && sudo systemctl reload nginx
sudo certbot --nginx -d DOMAIN
( crontab -l 2>/dev/null; echo "* * * * * cd /var/www/goyana/backend && php artisan schedule:run >> /dev/null 2>&1" ) | crontab -
```

## B. Jagoan Hosting / cPanel

1. cPanel → **Select PHP Version**: pilih 8.3, centang ekstensi di atas.
2. **MySQL Databases**: buat database, user, dan beri ALL PRIVILEGES.
3. **Terminal**:
   ```bash
   git clone https://github.com/rajabadutiklan-lab/Goyana.git ~/goyana
   cd ~/goyana/backend
   composer install --no-dev
   cp .env.example .env
   php artisan key:generate
   ```
   Isi `.env`, lalu jalankan `php artisan migrate --force` dan `php artisan goyana:admin`.
4. **Domains**: arahkan *Document Root* domain/subdomain ke `goyana/backend/public`. Aktifkan SSL (AutoSSL).
5. Jalankan `bash ~/goyana/deploy/build-web-app.sh https://DOMAIN`.
6. **Cron Jobs**, tiap menit:
   ```
   cd ~/goyana/backend && php artisan schedule:run >/dev/null 2>&1
   ```

## Isi `.env` produksi

```
APP_ENV=production
APP_DEBUG=false
APP_URL=https://DOMAIN
APP_TIMEZONE=UTC
DB_CONNECTION=mysql
DB_HOST=127.0.0.1
DB_DATABASE=goyana
DB_USERNAME=goyana
DB_PASSWORD=...
GOYANA_ADMIN_MFA=true
MAIL_MAILER=smtp        # isi SMTP (email domain/Brevo/dll) agar email verifikasi, reset & pesan otomatis terkirim
MAIL_HOST=... MAIL_PORT=587 MAIL_USERNAME=... MAIL_PASSWORD=... MAIL_FROM_ADDRESS=noreply@DOMAIN MAIL_FROM_NAME=GOYANA
GOYANA_REQUIRE_EMAIL_VERIFICATION=true   # setelah SMTP terbukti jalan
```

Jangan menaruh `.env` atau password di GitHub.

## Setelah online

1. Buka `https://DOMAIN/admin/system`. Semua harus hijau. Kuning artinya masih ada yang perlu diatur.
2. GitHub → Settings → Secrets and variables → Actions → **Variables** → `GOYANA_API_URL = https://DOMAIN`. APK berikutnya otomatis login ke server dan sinkron.
3. Owner membuka `https://DOMAIN/dashboard`, lalu tombol **Buka aplikasi GOYANA (web)** (`/app/`).
4. Update berikutnya cukup jalankan `bash deploy/update.sh`.

## Backup

- **VPS**: tambahkan cron harian
  ```
  mysqldump goyana | gzip > ~/backup/goyana-$(date +\%F).sql.gz
  ```
  Simpan salinannya di luar server (object storage/Google Drive). Hapus file yang lebih dari 30 hari.
- **cPanel**: aktifkan backup harian bawaan hosting, lalu unduh berkala.
