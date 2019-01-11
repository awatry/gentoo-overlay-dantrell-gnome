# Distributed under the terms of the GNU General Public License v2

EAPI="6"
PYTHON_COMPAT=( python2_7 )
PYTHON_REQ_USE="xml"

inherit autotools flag-o-matic gnome2-utils xdg toolchain-funcs python-single-r1

MY_P="${P/_/}"

DESCRIPTION="A SVG based generic vector-drawing program"
HOMEPAGE="https://inkscape.org/"
SRC_URI="https://inkscape.global.ssl.fastly.net/media/resources/file/${P}.tar.bz2"

LICENSE="GPL-2 LGPL-2.1"
SLOT="0"
KEYWORDS="~*"

IUSE="cdr dia dbus deprecated exif gnome imagemagick openmp postscript inkjar jpeg latex"
IUSE+=" lcms nls spell static-libs visio wpg"
REQUIRED_USE="${PYTHON_REQUIRED_USE}"

RESTRICT="test"

COMMON_DEPEND="${PYTHON_DEPS}
	>=app-text/poppler-0.26.0:=[cairo]
	<app-text/poppler-0.73.0:=
	>=dev-cpp/glibmm-2.28
	>=dev-cpp/gtkmm-2.18.0:2.4
	>=dev-cpp/cairomm-1.9.8
	>=dev-libs/boehm-gc-7.1:=
	>=dev-libs/glib-2.28
	>=dev-libs/libsigc++-2.0.12
	>=dev-libs/libxml2-2.6.20
	>=dev-libs/libxslt-1.0.15
	dev-libs/popt
	dev-python/lxml[${PYTHON_USEDEP}]
	media-gfx/potrace
	media-gfx/scour[${PYTHON_USEDEP}]
	media-libs/fontconfig
	media-libs/freetype:2
	media-libs/libpng:0
	sci-libs/gsl:=
	x11-libs/libX11
	>=x11-libs/gtk+-2.10.7:2
	>=x11-libs/pango-1.24
	cdr? (
		app-text/libwpg:0.3
		dev-libs/librevenge
		media-libs/libcdr
	)
	dbus? ( dev-libs/dbus-glib )
	!deprecated? ( >=dev-cpp/glibmm-2.48 )
	exif? ( media-libs/libexif )
	gnome? ( >=gnome-base/gnome-vfs-2.0 )
	imagemagick? ( media-gfx/imagemagick:=[cxx] )
	jpeg? ( virtual/jpeg:0 )
	lcms? ( media-libs/lcms:2 )
	spell? (
		app-text/aspell
		app-text/gtkspell:2
	)
	visio? (
		app-text/libwpg:0.3
		dev-libs/librevenge
		media-libs/libvisio
	)
	wpg? (
		app-text/libwpg:0.3
		dev-libs/librevenge
	)
"
# These only use executables provided by these packages
# See share/extensions for more details. inkscape can tell you to
# install these so we could of course just not depend on those and rely
# on that.
RDEPEND="${COMMON_DEPEND}
	dev-python/numpy[${PYTHON_USEDEP}]
	media-gfx/uniconvertor
	dia? ( app-office/dia )
	latex? (
		media-gfx/pstoedit[plotutils]
		app-text/dvipsk
		app-text/texlive-core
	)
	postscript? ( app-text/ghostscript-gpl )
"
DEPEND="${COMMON_DEPEND}
	>=dev-libs/boost-1.36:=
	>=dev-util/intltool-0.40
	>=sys-devel/gettext-0.17
	virtual/pkgconfig
"

PATCHES=(
	"${FILESDIR}"/${PN}-0.92.1-automagic.patch
	"${FILESDIR}"/${PN}-0.91_pre3-cppflags.patch
	"${FILESDIR}"/${PN}-0.92.1-desktop.patch
	"${FILESDIR}"/${PN}-0.91_pre3-exif.patch
	"${FILESDIR}"/${PN}-0.91_pre3-sk-man.patch
	"${FILESDIR}"/${PN}-0.48.4-epython.patch
	"${FILESDIR}"/${PN}-0.92.3-freetype_pkgconfig.patch
	"${FILESDIR}"/${PN}-0.92.3-poppler-0.64.patch
	"${FILESDIR}"/${PN}-0.92.3-poppler-0.65.patch
	"${FILESDIR}"/${PN}-0.92.3-poppler-0.64-2.patch
	"${FILESDIR}"/${PN}-0.92.3-poppler-0.69.patch
	"${FILESDIR}"/${PN}-0.92.3-poppler-0.71.patch
	"${FILESDIR}"/${PN}-0.92.3-poppler-0.72.patch
)

S="${WORKDIR}/${MY_P}"

pkg_pretend() {
	if use openmp; then
		tc-has-openmp || die "Please switch to an openmp compatible compiler"
	fi
}

src_prepare() {
	default

	sed -i "s#@EPYTHON@#${EPYTHON}#" \
		src/extension/implementation/script.cpp || die

	eautoreconf

	# bug 421111
	python_fix_shebang share/extensions
}

src_configure() {
	local myconf=()

	# aliasing unsafe wrt #310393
	append-flags -fno-strict-aliasing

	if use deprecated; then
		# disabling strict build required due to glibmm / glib2 deprecation misconfiguration
		# https://trac.macports.org/ticket/52248
		myconf+=(
			--disable-strict-build
		)
	fi

	local myeconfargs=(
		$(use_enable static-libs static)
		$(use_enable nls)
		$(use_enable openmp)
		$(use_enable exif)
		$(use_enable jpeg)
		$(use_enable lcms)
		--enable-poppler-cairo
		$(use_enable wpg)
		$(use_enable visio)
		$(use_enable cdr)
		$(use_enable dbus dbusapi)
		$(use_enable imagemagick magick)
		$(use_with gnome gnome-vfs)
		$(use_with inkjar)
		$(use_with spell gtkspell)
		$(use_with spell aspell)
		"${myconf[@]}"
	)
	econf "${myeconfargs[@]}"
}

src_compile() {
	emake AR="$(tc-getAR)"
}

src_install() {
	default

	find "${ED}" -name "*.la" -delete || die
	python_optimize "${ED%/}"/usr/share/${PN}/extensions
}

pkg_postinst() {
	gnome2_icon_cache_update
	xdg_mimeinfo_database_update
	xdg_desktop_database_update
}

pkg_postrm() {
	gnome2_icon_cache_update
	xdg_mimeinfo_database_update
	xdg_desktop_database_update
}