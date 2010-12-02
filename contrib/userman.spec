%define	version	0.2
%define odist	%{?dist}%{!?dist:.el4}
%define	release	%{odist}

Summary:	User Manager
Name:		userman
Version:	0.2
Release:	vit1
License:	MPL
Group:	Applications/System
URL:		http://vitki.net/v/Projects/UserMan
Source0:	%{name}-%{version}.tar.gz
Requires:	perl >= 5.8.0
BuildRoot: %{_tmppath}/%{name}-%{version}-%{release}-buildroot
BuildArch: noarch

%description
Manage LDAP Users and Groups

%prep
%setup -q

%build
echo OK

%install
[ "%{buildroot}" != "/" ] && rm -rf %{buildroot}

%define debug_package %{nil}
%define __perl_requires %{nil}

%define umdir  %{_datadir}/userman
%define picdir %{_datadir}/userman/images
%define appdir %{_datadir}/applications

install -d %{buildroot}%{_bindir}
install -m 0750 userman.pl %{buildroot}%{_bindir}/userman
install -d %{buildroot}%{_sysconfdir}
install -m 0644 userman.conf %{buildroot}%{_sysconfdir}
install -m 0600 userman.secret %{buildroot}%{_sysconfdir}
install -d %{buildroot}%{picdir}
install -m 0644 images/* %{buildroot}%{picdir}
install -d %{buildroot}%{appdir}
install -m 0644 userman.desktop %{buildroot}%{appdir}

%clean
[ "%{buildroot}" != "/" ] && rm -rf %{buildroot}

%files
%defattr(0644,root,root,0755)
%attr(0750,root,root) %{_bindir}/userman
%config(noreplace) %attr(0644,root,root) %{_sysconfdir}/userman.conf
%config(noreplace) %attr(0600,root,root) %{_sysconfdir}/userman.secret
%{umdir}
%{appdir}/userman.desktop

%changelog
* Tue Oct 07 2008 Victor Semizarov <vsemizarov$gmail,com> 0.8.0-03.RH
- rpm'ized

