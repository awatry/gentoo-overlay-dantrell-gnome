# Distributed under the terms of the GNU General Public License v2

EAPI="5"

inherit eutils flag-o-matic

DESCRIPTION="Scheme interpreter. Also The GNU extension language"
HOMEPAGE="http://www.gnu.org/software/guile/"
SRC_URI="mirror://gnu/guile/${P}.tar.gz"

LICENSE="LGPL-3+"
SLOT="12"
KEYWORDS="*"
IUSE="debug debug-malloc +deprecated emacs networking nls +regex static +threads"

RESTRICT="mirror"

RDEPEND="
	!dev-scheme/guile:2

	dev-libs/boehm-gc[threads?]
	dev-libs/gmp
	dev-libs/libffi
	dev-libs/libunistring
	sys-devel/libtool
	virtual/libiconv
	virtual/libintl

	emacs? ( virtual/emacs )"

DEPEND="${RDEPEND}
	virtual/pkgconfig"

src_configure() {
	# Seems to have issues with -Os, switch to -O2
	# 	https://bugs.funtoo.org/browse/FL-2584
	replace-flags -Os -O2

	econf \
		--disable-error-on-warning \
		--disable-rpath \
		--disable-static \
		--enable-posix \
		--with-modules \
		$(use_enable debug guile-debug) \
		$(use_enable debug-malloc) \
		$(use_enable deprecated) \
		$(use_enable networking) \
		$(use_enable nls) \
		$(use_enable regex) \
		$(use_enable static) \
		$(use_with threads)
}

src_install() {
	einstall

	dodoc AUTHORS COPYING COPYING.LESSER ChangeLog GUILE-VERSION HACKING LICENSE NEWS README THANKS || die

	# texmacs needs this, closing bug #23493
	dodir /etc/env.d
	echo "GUILE_LOAD_PATH=\"${EPREFIX}/usr/share/guile/${MAJOR}\"" > "${ED}"/etc/env.d/50guile

	# necessary for registering slib, see bug 206896
	keepdir /usr/share/guile/site

	if has_version dev-scheme/slib; then
		einfo "Registering slib with guile"
		install_slib_for_guile
		rm -f "${EROOT}"/usr/share/guile/site/slibcat
	fi

	# From Novell
	# 	https://bugzilla.novell.com/show_bug.cgi?id=874028#c0
	dodir /usr/share/gdb/auto-load/$(get_libdir)

	mv ${D}/usr/$(get_libdir)/libguile-*-gdb.scm ${D}/usr/share/gdb/auto-load/$(get_libdir)
}
