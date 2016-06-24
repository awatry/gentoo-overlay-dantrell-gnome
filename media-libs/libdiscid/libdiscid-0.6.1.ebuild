# Distributed under the terms of the GNU General Public License v2

EAPI="5"

inherit autotools-utils

DESCRIPTION="Client library to create MusicBrainz enabled tagging applications"
HOMEPAGE="http://musicbrainz.org/doc/libdiscid"
SRC_URI="http://ftp.musicbrainz.org/pub/musicbrainz/${PN}/${P}.tar.gz"

LICENSE="LGPL-2.1"
SLOT="0"
KEYWORDS="*"

IUSE="static-libs"

DOCS=( AUTHORS ChangeLog examples/discid.c README )