# Distributed under the terms of the GNU General Public License v2

EAPI="5"
GCONF_DEBUG="no"
PYTHON_COMPAT=( python2_7 )
PYTHON_REQ_USE="xml"

inherit autotools gnome2 python-r1 systemd versionator

DESCRIPTION="GNOME frontend for a Red Hat's printer administration tool"
HOMEPAGE="https://github.com/zdohnal/system-config-printer"
SRC_URI="https://github.com/zdohnal/${PN}/releases/download/${PV}/${P}.tar.xz"

LICENSE="GPL-2"
SLOT="0"
KEYWORDS="*"

IUSE="doc gnome-keyring policykit"
REQUIRED_USE="${PYTHON_REQUIRED_USE}"

# Needs cups running, bug 284005
RESTRICT="test"

RDEPEND="
	${PYTHON_DEPS}
	>=dev-libs/glib-2:2
	dev-libs/libxml2[python,${PYTHON_USEDEP}]
	dev-python/dbus-python[${PYTHON_USEDEP}]
	dev-python/pycairo[${PYTHON_USEDEP}]
	>=dev-python/pycups-1.9.60[${PYTHON_USEDEP}]
	dev-python/pycurl[${PYTHON_USEDEP}]
	dev-python/pygobject:3[${PYTHON_USEDEP}]
	net-print/cups[dbus]
	virtual/libusb:1
	>=virtual/udev-172
	x11-libs/gtk+:3[introspection]
	x11-libs/libnotify[introspection]
	x11-libs/pango[introspection]
	gnome-keyring? ( app-crypt/libsecret[introspection] )
	policykit? ( >=sys-auth/polkit-0.104-r1 )
	!app-admin/system-config-printer-common
	!app-admin/system-config-printer-gnome
"
DEPEND="${RDEPEND}
	app-text/docbook-xml-dtd:4.1.2
	>=app-text/xmlto-0.0.22
	dev-util/desktop-file-utils
	dev-util/intltool
	sys-devel/gettext
	virtual/pkgconfig
	doc? ( dev-python/epydoc[${PYTHON_USEDEP}] )
"

APP_LINGUAS="ar as bg bn_IN bn br bs ca cs cy da de el en_GB es et fa fi fr gu
he hi hr hu hy id is it ja ka kn ko lo lv mai mk ml mr ms nb nl nn or pa pl
pt_BR pt ro ru si sk sl sr@latin sr sv ta te th tr uk vi zh_CN zh_TW"
for X in ${APP_LINGUAS}; do
	IUSE="${IUSE} linguas_${X}"
done

# Bug 471472
MAKEOPTS+=" -j1"

src_prepare() {
	eautoreconf
	gnome2_src_prepare
}

src_configure() {
	local myconf

	# Disable installation of translations when LINGUAS not chosen
	if [[ -z "${LINGUAS}" ]]; then
		myconf="${myconf} --disable-nls"
	else
		myconf="${myconf} --enable-nls"
	fi

	gnome2_src_configure \
		--with-desktop-vendor=Gentoo \
		--with-udev-rules \
		$(systemd_with_unitdir) \
		${myconf}
}

src_compile() {
	gnome2_src_compile
	use doc && emake html
}

src_install() {
	gnome2_src_install
	use doc && dohtml -r html/
}
