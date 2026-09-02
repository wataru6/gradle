package net.rubygrapefruit.platform.internal

import net.rubygrapefruit.platform.NativeException
import net.rubygrapefruit.platform.SystemInfo
import spock.lang.Specification

class MutableSystemInfoTest extends Specification {
    def setupSpec() {
        println "MutableSystemInfo loaded from: ${MutableSystemInfo.protectionDomain.codeSource.location}"
    }

    def "recognizes macOS CPU brand string #processor"() {
        given:
        def info = new MutableSystemInfo(osName: "Darwin", machineArchitecture: processor)

        expect:
        info.architecture == architecture
        info.architectureName == architectureName

        where:
        processor                                    | architecture                    | architectureName
        "Intel(R) Core(TM) i5-8500 CPU @ 3.00GHz"      | SystemInfo.Architecture.amd64    | "x86_64"
        "Intel(R) Xeon(R) W-3223 CPU @ 3.50GHz"        | SystemInfo.Architecture.amd64    | "x86_64"
        "11th Gen Intel(R) Core(TM) i7-11800H @ 2.30GHz" | SystemInfo.Architecture.amd64  | "x86_64"
        "12th Gen Intel(R) Core(TM) i7-12650HX"        | SystemInfo.Architecture.amd64    | "x86_64"
        "13th Gen Intel(R) Core(TM) i5-13600K"         | SystemInfo.Architecture.amd64    | "x86_64"
        "14th Gen Intel(R) Core(TM) i9-14900K"         | SystemInfo.Architecture.amd64    | "x86_64"
        "Intel(R) Core(TM) Ultra 7 255H"               | SystemInfo.Architecture.amd64    | "x86_64"
        "AMD Ryzen 5 2600 Six-Core Processor"          | SystemInfo.Architecture.amd64    | "x86_64"
        "AMD Ryzen 9 9950X 16-Core Processor"          | SystemInfo.Architecture.amd64    | "x86_64"
        "Apple M1"                                   | SystemInfo.Architecture.aarch64  | "arm64"
        "Apple M4 Pro"                               | SystemInfo.Architecture.aarch64  | "arm64"
    }

    def "preserves architecture aliases on #osName"() {
        given:
        def info = new MutableSystemInfo(osName: osName, machineArchitecture: machine)

        expect:
        info.architectureName == machine
        info.architecture == architecture

        where:
        osName    | machine   | architecture
        "Linux"   | "amd64"   | SystemInfo.Architecture.amd64
        "Linux"   | "x86_64"  | SystemInfo.Architecture.amd64
        "Windows" | "amd64"   | SystemInfo.Architecture.amd64
        "Linux"   | "i386"    | SystemInfo.Architecture.i386
        "Linux"   | "i686"    | SystemInfo.Architecture.i386
        "Windows" | "x86"     | SystemInfo.Architecture.i386
        "Linux"   | "aarch64" | SystemInfo.Architecture.aarch64
        "Darwin"  | "arm64"   | SystemInfo.Architecture.aarch64
        "Darwin"  | "x86_64"  | SystemInfo.Architecture.amd64
    }

    def "does not guess the architecture of unknown CPU brands"() {
        given:
        def info = new MutableSystemInfo(osName: "Darwin", machineArchitecture: "Unknown CPU")

        when:
        info.architecture

        then:
        thrown(NativeException)
    }
}
