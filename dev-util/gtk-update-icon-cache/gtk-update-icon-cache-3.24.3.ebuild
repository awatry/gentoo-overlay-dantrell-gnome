# Distributed under the terms of the GNU General Public License v2

EAPI="6"

inherit gnome2

DESCRIPTION="GTK update icon cache"
HOMEPAGE="https://www.gtk.org/ https://github.com/EvaSDK/gtk-update-icon-cache"
SRC_URI="https://dev.gentoo.org/~leio/distfiles/${PN}/${P}.tar.xz"

LICENSE="LGPL-2+"
SLOT="0"
KEYWORDS="*"

IUSE=""

# man page was previously installed by gtk+:3 ebuild
RDEPEND="
	>=dev-libs/glib-2.53.4:2
	>=x11-libs/gdk-pixbuf-2.30:2
	!<x11-libs/gtk+-2.24.28-r1:2
	!<x11-libs/gtk+-3.22.2:3
"
DEPEND="${RDEPEND}
	>=sys-devel/gettext-0.19.7
	virtual/pkgconfig
"

src_configure() {
	# man pages are shipped in tarball
	gnome2_src_configure --disable-man
}

src_install() {
	gnome2_src_install
	doman docs/${PN}.1
}
