package main

import (
	"fmt"
	"net/netip"
	"os"
)

func usage() {
	fmt.Fprintf(os.Stderr, `Usage:
  %s addr <ipv6-address>
  %s prefix <ipv6-prefix>
  %s contains <ipv6-address> <ipv6-prefix>

Examples:
  %s addr 2001:db8::1
  %s prefix 2001:db8::/32
  %s contains 2001:db8::42 2001:db8::/32
`, os.Args[0], os.Args[0], os.Args[0], os.Args[0], os.Args[0], os.Args[0])
	os.Exit(2)
}

func main() {
	if len(os.Args) < 3 {
		usage()
	}

	cmd := os.Args[1]

	switch cmd {
	case "addr":
		addr, err := netip.ParseAddr(os.Args[2])
		if err != nil || !addr.Is6() {
			fmt.Println("INVALID")
			os.Exit(1)
		}
		fmt.Println("VALID")

	case "prefix":
		pfx, err := netip.ParsePrefix(os.Args[2])
		if err != nil || !pfx.Addr().Is6() {
			fmt.Println("INVALID")
			os.Exit(1)
		}
		fmt.Println("VALID")

	case "contains":
		if len(os.Args) != 4 {
			usage()
		}

		addr, err1 := netip.ParseAddr(os.Args[2])
		pfx, err2 := netip.ParsePrefix(os.Args[3])

		if err1 != nil || err2 != nil || !addr.Is6() || !pfx.Addr().Is6() {
			fmt.Println("INVALID")
			os.Exit(1)
		}

		if pfx.Contains(addr) {
			fmt.Println("YES")
			os.Exit(0)
		}

		fmt.Println("NO")
		os.Exit(1)

	default:
		usage()
	}
}
