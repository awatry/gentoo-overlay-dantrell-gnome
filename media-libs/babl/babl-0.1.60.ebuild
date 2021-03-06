# Distributed under the terms of the GNU General Public License v2

EAPI="6"

inherit ltprune

DESCRIPTION="A dynamic, any to any, pixel format conversion library"
HOMEPAGE="http://www.gegl.org/babl/"
SRC_URI="http://ftp.gimp.org/pub/${PN}/${PV:0:3}/${P}.tar.bz2"

LICENSE="LGPL-3"
SLOT="0"
KEYWORDS="~*"

IUSE="altivec cpu_flags_x86_sse cpu_flags_x86_sse2 cpu_flags_x86_sse3 cpu_flags_x86_sse4_1 cpu_flags_x86_mmx cpu_flags_x86_f16c"

RDEPEND=""
DEPEND="${RDEPEND}
	>=sys-devel/libtool-2.2
	virtual/pkgconfig
"

src_prepare() {
	default
	eautoreconf
}

src_configure() {
	# Automagic rsvg support is just for website generation we do not call,
	#     so we don't need to fix it
	# w3m is used for dist target thus no issue for us that it is automagically
	#     detected
	econf \
		--disable-docs \
		--disable-static \
		--disable-maintainer-mode \
		$(use_enable altivec) \
		$(use_enable cpu_flags_x86_f16c f16c) \
		$(use_enable cpu_flags_x86_mmx mmx) \
		$(use_enable cpu_flags_x86_sse sse) \
		$(use_enable cpu_flags_x86_sse2 sse2) \
		$(use_enable cpu_flags_x86_sse3 sse3) \
		$(use_enable cpu_flags_x86_sse4_1 sse4_1)
}

src_install() {
	default
	prune_libtool_files --all
}
