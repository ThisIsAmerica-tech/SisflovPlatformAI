# Usamos una imagen oficial de PHP con Apache
FROM php:8.2-apache

# Instalamos dependencias del sistema necesarias para Laravel y PostgreSQL
RUN apt-get update && apt-get install -y \
    libpng-dev \
    libonig-dev \
    libxml2-dev \
    zip \
    unzip \
    libpq-dev \
    git \
    curl

# Limpiamos caché de apt
RUN apt-get clean && rm -rf /var/lib/apt/lists/*

# Instalamos extensiones de PHP necesarias
RUN docker-php-ext-install pdo pdo_pgsql mbstring exif pcntl bcmath gd

# Habilitamos mod_rewrite de Apache para que las rutas de Laravel funcionen
RUN a2enmod rewrite

# Configuramos el DocumentRoot de Apache para que apunte a la carpeta public de Laravel
ENV APACHE_DOCUMENT_ROOT /var/www/html/public
RUN sed -ri -e 's!/var/www/html!${APACHE_DOCUMENT_ROOT}!g' /etc/apache2/sites-available/*.conf
RUN sed -ri -e 's!/var/www/!${APACHE_DOCUMENT_ROOT}!g' /etc/apache2/apache2.conf /etc/apache2/conf-available/*.conf

# Copiamos el composer desde la imagen oficial
COPY --from=composer:latest /usr/bin/composer /usr/bin/composer

# Copiamos todo el código de nuestra carpeta backend al contenedor
COPY . /var/www/html

# Damos los permisos correctos a las carpetas de Laravel
RUN chown -R www-data:www-data /var/www/html/storage /var/www/html/bootstrap/cache

# Instalamos dependencias de Composer (optimizadas para producción)
RUN composer install --optimize-autoloader --no-dev

# Exponemos el puerto 80 (el que usa Render por defecto)
EXPOSE 80