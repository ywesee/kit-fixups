# Copyright 1999-2019 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=5
PYTHON_COMPAT=(python{2_7,3_4} pypy)
inherit distutils-r1

DESCRIPTION="An implementation of JSON-Schema validation for Python"
HOMEPAGE="https://pypi.org/project/jsonschema/"
SRC_URI="mirror://pypi/${PN:0:1}/${PN}/${P}.tar.gz"

LICENSE="MIT"
SLOT="0"
KEYWORDS="amd64 ~ppc ~ppc64 x86 ~amd64-linux ~x86-linux"
IUSE="test"

python_test() {
	local runner=( "${PYTHON}" -m unittest )
	if [[ ${EPYTHON} == python2.6 || ${EPYTHON} == python3.1 ]]; then
		unset PYTHONPATH
		runner=( unit2.py )
	fi
	"${runner[@]}" discover || die "Testing failed with ${EPYTHON}"
}
