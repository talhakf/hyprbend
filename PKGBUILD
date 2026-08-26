# Maintainer: kosmosys
pkgname=hyprbend
pkgver=0.1.0
pkgrel=1
pkgdesc="Automatic screen rotation and keyboard toggle for 2-in-1 laptops on Hyprland"
arch=('any')
url="https://github.com/kosmosys/hyprbend"
license=('MIT')
depends=('hyprland' 'iio-sensor-proxy' 'bash')
makedepends=()
source=('hyprbend' 'hyprbend.service')
sha256sums=('SKIP' 'SKIP')
install=hyprbend.install

package() {
    # Install main script
    install -Dm755 "$srcdir/hyprbend" "$pkgdir/usr/bin/hyprbend"

    # Install systemd user service
    install -Dm644 "$srcdir/hyprbend.service" "$pkgdir/usr/lib/systemd/user/hyprbend.service"
}
