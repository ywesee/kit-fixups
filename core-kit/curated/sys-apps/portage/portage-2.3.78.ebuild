# Copyright 1999-2019 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=5

PYTHON_COMPAT=(
	pypy
	python3_5 python3_6 python3_7
	python2_7
)
PYTHON_REQ_USE='bzip2(+),threads(+)'

inherit distutils-r1 linux-info systemd prefix

DESCRIPTION="Portage is the package management and distribution system for Gentoo"
HOMEPAGE="https://wiki.gentoo.org/wiki/Project:Portage"

LICENSE="GPL-2"
KEYWORDS="*"
SLOT="0"
IUSE="build doc epydoc gentoo-dev +ipc +native-extensions -rsync-verify selinux xattr"

DEPEND="!build? ( $(python_gen_impl_dep 'ssl(+)') )
	>=app-arch/tar-1.27
	dev-lang/python-exec:2
	>=sys-apps/sed-4.0.5 sys-devel/patch
	doc? ( app-text/xmlto ~app-text/docbook-xml-dtd-4.4 )
	epydoc? ( >=dev-python/epydoc-2.0[$(python_gen_usedep 'python2*')] )"
# Require sandbox-2.2 for bug #288863.
# For xattr, we can spawn getfattr and setfattr from sys-apps/attr, but that's
# quite slow, so it's not considered in the dependencies as an alternative to
# to python-3.3 / pyxattr. Also, xattr support is only tested with Linux, so
# for now, don't pull in xattr deps for other kernels.
# For whirlpool hash, require python[ssl] (bug #425046).
# For compgen, require bash[readline] (bug #445576).
# app-portage/gemato goes without PYTHON_USEDEP since we're calling
# the executable.
RDEPEND="
	>=app-arch/tar-1.27
	dev-lang/python-exec:2
	!build? (
		>=sys-apps/sed-4.0.5
		app-shells/bash:0[readline]
		>=app-admin/eselect-1.2
		$(python_gen_cond_dep 'dev-python/pyblake2[${PYTHON_USEDEP}]' \
			python{2_7,3_5} pypy)
		rsync-verify? (
			>=app-portage/gemato-14[${PYTHON_USEDEP}]
			>=app-crypt/openpgp-keys-gentoo-release-20180706
			>=app-crypt/gnupg-2.2.4-r2[ssl(-)]
		)
	)
	elibc_FreeBSD? ( sys-freebsd/freebsd-bin )
	elibc_glibc? ( >=sys-apps/sandbox-2.2 )
	elibc_musl? ( >=sys-apps/sandbox-2.2 )
	elibc_uclibc? ( >=sys-apps/sandbox-2.2 )
	kernel_linux? ( sys-apps/util-linux )
	>=app-misc/pax-utils-0.1.17
	selinux? ( >=sys-libs/libselinux-2.0.94[python,${PYTHON_USEDEP}] )
	xattr? ( kernel_linux? (
		>=sys-apps/install-xattr-0.3
		$(python_gen_cond_dep 'dev-python/pyxattr[${PYTHON_USEDEP}]' \
			python2_7 pypy)
	) )
	!<app-admin/logrotate-3.8.0
	!<app-portage/gentoolkit-0.4.6
	!<app-portage/repoman-2.3.10"
PDEPEND="
	!build? (
		>=net-misc/rsync-2.6.4
		userland_GNU? ( >=sys-apps/coreutils-6.4 )
	)
	app-admin/ego"
# coreutils-6.4 rdep is for date format in emerge-webrsync #164532
# NOTE: FEATURES=installsources requires debugedit and rsync

REQUIRED_USE="epydoc? ( $(python_gen_useflags 'python2*') )"

SRC_ARCHIVES="https://dev.gentoo.org/~zmedico/portage/archives"

prefix_src_archives() {
	local x y
	for x in ${@}; do
		for y in ${SRC_ARCHIVES}; do
			echo ${y}/${x}
		done
	done
}

TARBALL_PV=${PV}

pkg_pretend() {
	local CONFIG_CHECK="~IPC_NS ~PID_NS ~NET_NS"

	check_extra_config
}

GITHUB_REPO="$PN-gentoo"
GITHUB_USER="funtoo"
GITHUB_TAG="bac24951adfacbc87bcbf22a4724f1dc7ca52f2b"
SRC_URI="https://www.github.com/${GITHUB_USER}/${GITHUB_REPO}/tarball/${GITHUB_TAG} -> ${PN}-${GITHUB_TAG}.tar.gz"

src_unpack() {
	unpack ${A}
	mv "${WORKDIR}/${GITHUB_USER}-${GITHUB_REPO}"-??????? "${S}" || die
}

pkg_setup() {
	use epydoc && DISTUTILS_ALL_SUBPHASE_IMPLS=( python2.7 )
}

PATCHES=(
	"${FILESDIR}/${PN}-2.4.3-remove-gentoo-repos-conf.patch"
	"${FILESDIR}/${PN}-2.3.68-change-global-paths.patch"
	"${FILESDIR}/${PN}-2.3.41-ebuild-nodie.patch"
	"${FILESDIR}/portage-2.3.68-set-backtracking-to-6.patch"
	"${FILESDIR}/portage-2.3.68-allow-matches-in-package-updates.patch"
)

python_prepare_all() {
	distutils-r1_python_prepare_all

	# apply f4aa49bc1ba2
	sed -e 's|^export -n -f ___in_portage_iuse$|declare -F ___in_portage_iuse >/dev/null \&\& \0|' \
		-i bin/ebuild.sh || die

	if use gentoo-dev; then
		einfo "Disabling --dynamic-deps by default for gentoo-dev..."
		sed -e 's:\("--dynamic-deps", \)\("y"\):\1"n":' \
			-i lib/_emerge/create_depgraph_params.py || \
			die "failed to patch create_depgraph_params.py"

		einfo "Enabling additional FEATURES for gentoo-dev..."
		echo 'FEATURES="${FEATURES} ipc-sandbox network-sandbox strict-keepdir"' \
			>> cnf/make.globals || die
	fi

	if use native-extensions; then
		printf "[build_ext]\nportage-ext-modules=true\n" >> \
			setup.cfg || die
	fi

	if ! use ipc ; then
		einfo "Disabling ipc..."
		sed -e "s:_enable_ipc_daemon = True:_enable_ipc_daemon = False:" \
			-i lib/_emerge/AbstractEbuildProcess.py || \
			die "failed to patch AbstractEbuildProcess.py"
	fi

	if use xattr && use kernel_linux ; then
		einfo "Adding FEATURES=xattr to make.globals ..."
		echo -e '\nFEATURES="${FEATURES} xattr"' >> cnf/make.globals \
			|| die "failed to append to make.globals"
	fi

	if use build || ! use rsync-verify; then
		sed -e '/^sync-rsync-verify-metamanifest/s|yes|no|' \
			-i cnf/repos.conf || die "sed failed"
	fi
	echo "Enabling fastpull-us..."
	sed -e "s|^GENTOO_MIRRORS=.*$|GENTOO_MIRRORS=https://fastpull-us.funtoo.org|" -i cnf/make.globals || die "sed failed"
 
 
	if [[ -n ${EPREFIX} ]] ; then
		einfo "Setting portage.const.EPREFIX ..."
		hprefixify -e "s|^(EPREFIX[[:space:]]*=[[:space:]]*\").*|\1${EPREFIX}\"|" \
			-w "/_BINARY/" lib/portage/const.py

		einfo "Prefixing shebangs ..."
		while read -r -d $'\0' ; do
			local shebang=$(head -n1 "$REPLY")
			if [[ ${shebang} == "#!"* && ! ${shebang} == "#!${EPREFIX}/"* ]] ; then
				sed -i -e "1s:.*:#!${EPREFIX}${shebang:2}:" "$REPLY" || \
					die "sed failed"
			fi
		done < <(find . -type f ! -name etc-update -print0)

		einfo "Adjusting make.globals, repos.conf and etc-update ..."
		hprefixify cnf/{make.globals,repos.conf} bin/etc-update

		if use prefix-guest ; then
			sed -e "s|^\(main-repo = \).*|\\1gentoo_prefix|" \
				-e "s|^\\[gentoo\\]|[gentoo_prefix]|" \
				-e "s|^\(sync-uri = \).*|\\1rsync://rsync.prefix.bitzolder.nl/gentoo-portage-prefix|" \
				-i cnf/repos.conf || die "sed failed"
		fi

		einfo "Adding FEATURES=force-prefix to make.globals ..."
		echo -e '\nFEATURES="${FEATURES} force-prefix"' >> cnf/make.globals \
			|| die "failed to append to make.globals"
	fi

	cd "${S}/cnf" || die
	if [ -f "make.conf.example.${ARCH}".diff ]; then
		patch make.conf.example "make.conf.example.${ARCH}".diff || \
			die "Failed to patch make.conf.example"
	else
		eerror ""
		eerror "Portage does not have an arch-specific configuration for this arch."
		eerror "Please notify the arch maintainer about this issue. Using generic."
		eerror ""
	fi
}

python_compile_all() {
	local targets=()
	use doc && targets+=( docbook )
	use epydoc && targets+=( epydoc )

	if [[ ${targets[@]} ]]; then
		esetup.py "${targets[@]}"
	fi
}

python_test() {
	esetup.py test
}

python_install() {
	# Install sbin scripts to bindir for python-exec linking
	# they will be relocated in pkg_preinst()
	distutils-r1_python_install \
		--system-prefix="${EPREFIX}/usr" \
		--bindir="$(python_get_scriptdir)" \
		--docdir="${EPREFIX}/usr/share/doc/${PF}" \
		--htmldir="${EPREFIX}/usr/share/doc/${PF}/html" \
		--portage-bindir="${EPREFIX}/usr/lib/portage/${EPYTHON}" \
		--sbindir="$(python_get_scriptdir)" \
		--sysconfdir="${EPREFIX}/etc" \
		"${@}"
}

python_install_all() {
	distutils-r1_python_install_all

	local targets=()
	use doc && targets+=(
		install_docbook
		--htmldir="${EPREFIX}/usr/share/doc/${PF}/html"
	)
	use epydoc && targets+=(
		install_epydoc
		--htmldir="${EPREFIX}/usr/share/doc/${PF}/html"
	)

	# install docs
	if [[ ${targets[@]} ]]; then
		esetup.py "${targets[@]}"
	fi

	systemd_dotmpfilesd "${FILESDIR}"/portage-ccache.conf

	# Due to distutils/python-exec limitations
	# these must be installed to /usr/bin.
	local sbin_relocations='archive-conf dispatch-conf emaint env-update etc-update fixpackages regenworld'
	einfo "Moving admin scripts to the correct directory"
	dodir /usr/sbin
	for target in ${sbin_relocations}; do
		einfo "Moving /usr/bin/${target} to /usr/sbin/${target}"
		mv "${ED}usr/bin/${target}" "${ED}usr/sbin/${target}" || die "sbin scripts move failed!"
	done

	# remove webrsync binary that will break Funtoo's meta-repo if accidentally used.
	rm ${ED}usr/bin/emerge-webrsync || die "rm failed"
}

pkg_preinst() {
	python_setup
	python_export PYTHON_SITEDIR
	[[ -d ${D%/}${PYTHON_SITEDIR} ]] || die "${D%/}${PYTHON_SITEDIR}: No such directory"
	env -u DISTDIR \
		-u PORTAGE_OVERRIDE_EPREFIX \
		-u PORTAGE_REPOSITORIES \
		-u PORTDIR \
		-u PORTDIR_OVERLAY \
		PYTHONPATH="${D%/}${PYTHON_SITEDIR}${PYTHONPATH:+:${PYTHONPATH}}" \
		"${PYTHON}" -m portage._compat_upgrade.default_locations || die

	# elog dir must exist to avoid logrotate error for bug #415911.
	# This code runs in preinst in order to bypass the mapping of
	# portage:portage to root:root which happens after src_install.
	keepdir /var/log/portage/elog
	# This is allowed to fail if the user/group are invalid for prefix users.
	if chown portage:portage "${ED}"var/log/portage{,/elog} 2>/dev/null ; then
		chmod g+s,ug+rwx "${ED}"var/log/portage{,/elog}
	fi
}
