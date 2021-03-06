
BUILD=build

JAVA=java
JAVAC=javac
JAR=jar

UNAME=$(shell uname)

ifneq (, $(wildcard Makefile.local))
include Makefile.local
endif

ifeq ($(UNAME), Darwin)
  CXXFLAGS+=-std=c++1z
  CXXFLAGS+=-stdlib=libc++
  R=r
else ifeq ($(UNAME), Linux)
  CXXFLAGS+=-std=c++0x
  CXXFLAGS+=-lrt
  R=R
else
  $(error Unrecognized environment. Only supported Darwin and Linux)
endif

CXXFLAGS+=-MMD -fPIC -O2 # -W -g -Wall -Wextra -O0


# CPP_SRCS=$(shell find src-* -name "*.cpp")
# CPP_OBJS=$(CPP_SRCS:src-%=$(BUILD)/%.o)
# hola:
# # @echo $(CPP_SRCS)
# 	@echo $(CPP_OBJS)

#
# Rules to make $(JNIF)
#
JNIF=$(BUILD)/libjnif.a
JNIF_BUILD=$(BUILD)/libjnif
JNIF_SRC=src-libjnif
JNIF_SRCS=$(wildcard $(JNIF_SRC)/*.cpp) $(wildcard $(JNIF_SRC)/*/*.cpp)
JNIF_OBJS=$(JNIF_SRCS:$(JNIF_SRC)/%=$(JNIF_BUILD)/%.o)

$(JNIF): $(JNIF_OBJS)
	$(AR) cr $@ $^

$(JNIF_BUILD)/%.cpp.o: $(JNIF_SRC)/%.cpp | $(JNIF_BUILD) $(JNIF_BUILD)/parser $(JNIF_BUILD)/jar
	$(CXX) $(CXXFLAGS) -I$(JNIF_SRC) -c -o $@ $<

-include $(JNIF_BUILD)/*.cpp.d
-include $(JNIF_BUILD)/**/*.cpp.d

$(JNIF_BUILD):
	mkdir -p $@

$(JNIF_BUILD)/parser:
	mkdir -p $@

$(JNIF_BUILD)/jar:
	mkdir -p $@

#
# Rules to make $(TESTUNIT)
#
TESTUNIT=$(BUILD)/testunit.bin
TESTUNIT_BUILD=$(BUILD)/testunit
TESTUNIT_SRC=src-testunit
TESTUNIT_SRCS=$(wildcard $(TESTUNIT_SRC)/*.cpp)
TESTUNIT_OBJS=$(TESTUNIT_SRCS:$(TESTUNIT_SRC)/%=$(TESTUNIT_BUILD)/%.o)

run-testunit: $(TESTUNIT)
	$(TESTUNIT)

testunit: $(TESTUNIT)

$(TESTUNIT): $(TESTUNIT_OBJS) $(JNIF)
	$(CXX) $(CXXFLAGS) -o $@ $^

$(TESTUNIT_BUILD)/%.cpp.o: $(TESTUNIT_SRC)/%.cpp | $(TESTUNIT_BUILD)
	$(CXX) $(CXXFLAGS) -I$(JNIF_SRC) -c -o $@ $<

$(TESTUNIT_BUILD):
	mkdir -p $@

#
# Rules for $(TESTJARS)
#
TESTJARS=$(BUILD)/testjars.bin
TESTJARS_BUILD=$(BUILD)/testjars
TESTJARS_SRC=src-testjars
TESTJARS_SRCS=$(wildcard $(TESTJARS_SRC)/*.cpp)
TESTJARS_OBJS=$(TESTJARS_SRCS:$(TESTJARS_SRC)/%=$(TESTJARS_BUILD)/%.o)
JARS=$(wildcard jars/*.jar)

run-testjars: $(TESTJARS)
	$(TESTJARS) $(JARS)

testjars: $(TESTJARS)

$(TESTJARS): LDFLAGS=-lz
$(TESTJARS): $(TESTJARS_OBJS) $(JNIF)
	$(CXX) $(LDFLAGS) -o $@ $^

$(TESTJARS_BUILD)/%.cpp.o: $(TESTJARS_SRC)/%.cpp | $(TESTJARS_BUILD)
	$(CXX) $(CXXFLAGS) -I$(JNIF_SRC) -c -o $@ $<

$(TESTJARS_BUILD):
	mkdir -p $@

#
# Rules to make $(JNIFP)
#
JNIFP=$(BUILD)/jnifp.mach-o
JNIFP_BUILD=$(BUILD)/jnifp
JNIFP_SRC=src-jnifp
JNIFP_SRCS=$(wildcard $(JNIFP_SRC)/*.cpp)
JNIFP_OBJS=$(JNIFP_SRCS:$(JNIFP_SRC)/%=$(JNIFP_BUILD)/%.o)
JNIFP_JAVAS=$(wildcard classes/*.java)
JNIFP_CLASSES=$(JNIFP_JAVAS:%.java=$(BUILD)/%.class)

run-jnifp: $(JNIFP) $(JNIFP_CLASSES)
	$(JNIFP) $(BUILD)/classes/Generic.class

jnifp: $(JNIFP)

$(JNIFP): $(JNIFP_OBJS) $(JNIF)
	$(CXX) $(CXXFLAGS) -o $@ $^

$(JNIFP_BUILD)/%.cpp.o: $(JNIFP_SRC)/%.cpp | $(JNIFP_BUILD)
	$(CXX) $(CXXFLAGS) -I$(JNIF_SRC) -c -o $@ $<

-include $(JNIFP_BUILD)/*.cpp.d

$(BUILD)/%.class: %.java | $(BUILD)/classes
	javac -d $(BUILD)/classes $<

$(JNIFP_BUILD):
	mkdir -p $@

$(BUILD)/classes:
	mkdir -p $@

#
# Rules to make $(TESTAGENT)
#
TESTAGENT=$(BUILD)/libtestagent.dylib
TESTAGENT_BUILD=$(BUILD)/libtestagent
TESTAGENT_SRC=src-testagent
TESTAGENT_HPPS=$(wildcard $(TESTAGENT_SRC)/*.hpp) $(LIBJNIF_HPPS)
TESTAGENT_SRCS=$(wildcard $(TESTAGENT_SRC)/*.cpp) $(wildcard $(TESTAGENT_SRC)/frproxy/*.java)
TESTAGENT_OBJS=$(TESTAGENT_SRCS:$(TESTAGENT_SRC)/%=$(TESTAGENT_BUILD)/%.o)

$(TESTAGENT): $(TESTAGENT_OBJS) $(JNIF)
	$(CXX) -fPIC -g -lpthread -shared -lstdc++ -o $@ $^ $(CXXFLAGS)

$(TESTAGENT_BUILD)/%.cpp.o: $(TESTAGENT_SRC)/%.cpp $(TESTAGENT_HPPS) | $(TESTAGENT_BUILD)
	$(CXX) $(CXXFLAGS) -I$(JNIF_SRC) -Wno-unused-parameter -I$(JAVA_HOME)/include/darwin -I$(JAVA_HOME)/include -c -o $@ $<

$(TESTAGENT_BUILD)/%.java.o: $(TESTAGENT_SRC)/%.java
	$(JAVAC) -d $(TESTAGENT_BUILD)/ $<
	cd $(TESTAGENT_BUILD) && xxd -i $*.class $*.c
	$(LINK.c) -c -o $@ $(TESTAGENT_BUILD)/$*.c

$(TESTAGENT_BUILD):
	mkdir -p $@
	mkdir -p $(BUILD)/instr

#
# Rules to make $(TESTAPP)
#
TESTAPP=$(BUILD)/testapp.jar
TESTAPP_BUILD=$(BUILD)/testapp
TESTAPP_SRC=src-testapp
TESTAPP_SRCS=$(wildcard $(TESTAPP_SRC)/*/*.java)
TESTAPP_SRCS+=$(wildcard $(TESTAPP_SRC)/*/*/*.java)
TESTAPP_OBJS=$(TESTAPP_SRCS:$(TESTAPP_SRC)/%.java=$(TESTAPP_BUILD)/%.class)

$(TESTAPP): $(TESTAPP_SRC)/MANIFEST.MF $(TESTAPP_OBJS)
	$(JAR) cfm $@ $< -C $(TESTAPP_BUILD) .

$(TESTAPP_BUILD)/%.class: $(TESTAPP_SRC)/%.java | $(TESTAPP_BUILD)
	$(JAVAC) -sourcepath $(TESTAPP_SRC) -d $(TESTAPP_BUILD) $<

$(TESTAPP_BUILD):
	mkdir -p $@

#
# Rules to make $(INSTRSERVER)
#
INSTRSERVER=$(BUILD)/instrserver.jar
INSTRSERVER_BUILD=$(BUILD)/instrserver
INSTRSERVER_SRC=src-instrserver
INSTRSERVER_SRCS=$(shell find $(INSTRSERVER_SRC) -name *.java)
INSTRSERVER_OBJS=$(INSTRSERVER_BUILD)/log4j.properties $(INSTRSERVER_SRCS:$(INSTRSERVER_SRC)/src/%.java=$(INSTRSERVER_BUILD)/%.class)
INSTRSERVER_CP=$(subst $(_EMPTY) $(_EMPTY),:,$(wildcard $(INSTRSERVER_SRC)/lib/*.jar))

$(INSTRSERVER): $(INSTRSERVER_SRC)/MANIFEST.MF $(INSTRSERVER_OBJS)
	$(JAR) cfm $@ $< -C $(INSTRSERVER_BUILD) .

$(INSTRSERVER_BUILD)/%.class: $(INSTRSERVER_SRC)/src/%.java | $(INSTRSERVER_BUILD)
	$(JAVAC) -classpath $(INSTRSERVER_CP) -sourcepath $(INSTRSERVER_SRC)/src -d $(INSTRSERVER_BUILD) $<

$(INSTRSERVER_BUILD)/%: $(INSTRSERVER_SRC)/src/% | $(INSTRSERVER_BUILD)
	cp $< $@

$(INSTRSERVER_BUILD):
	mkdir -p $@

#
# PHONY rules
#

.PHONY: all testunit start stop testapp dacapo docs clean cleaneval

all: $(LIBJNIF) $(TESTUNIT) $(TESTCOVERAGE) $(TESTAGENT) $(TESTAPP) $(INSTRSERVER)


#
# Rules to run $(INSTRSERVER)
#
start: CLASSPREFIX=ch.usi.inf.sape.frheap.FrHeapInstrumenter
start:
	$(JAVA) -jar $(INSTRSERVER) $(CLASSPREFIX)$(INSTRSERVERCLASS) instrserver,$(APP),$(RUN),$(INSTR) &
	sleep 2

stop:
	kill `jps -mlv | grep $(INSTRSERVER) | cut -f 1 -d' '`
	sleep 1

runjar:
	time $(JAVA) $(JVMARGS) -jar $(JARAPP)

CMD=runjar

runagent: LOGDIR=$(BUILD)/run/$(APP)/log/$(INSTR).$(APP)
runagent: PROF=$(BUILD)/eval-$(BACKEND)-$(APP)-$(RUN)-$(INSTR)
runagent: JVMARGS+=-agentpath:$(TESTAGENT)=$(FUNC):$(PROF):$(LOGDIR)/:$(BACKEND),$(APP),$(RUN),$(INSTR)
runagent: logdir $(TESTAGENT) $(CMD)
	cat $(PROF).tid-*.prof > $(PROF).prof
	rm $(PROF).tid-*.prof

logdir:
	mkdir -p $(LOGDIR)

runserver: INSTRSERVERCLASS=$(INSTR)
runserver: FUNC=ClientServer
runserver: $(INSTRSERVER) start runagent stop

#cat $(BUILD)/eval-instrserver-instrserver,$(APP),$(RUN),$(INSTR)-*.prof > $(BUILD)/eval.$(UNAME).prof

RUN=4
INSTR=Compute
FUNC=$(INSTR)
BACKEND=runagent

testapp: JARAPP:=$(TESTAPP)
testapp: APP=jnif-testapp
testapp: $(TESTAPP)
testapp: $(BACKEND)

BENCH=avrora

DACAPO_SCRATCH=$(BUILD)/run/dacapo/scratch/$(INSTR).$(BENCH)

dacapo: JARAPP=jars/dacapo-9.12-bach.jar --scratch-directory $(DACAPO_SCRATCH) $(BENCH)
dacapo: APP=dacapo-$(BENCH)
dacapo: | $(DACAPO_SCRATCH)
dacapo: $(BACKEND)

$(DACAPO_SCRATCH):
	mkdir -p $@

scala: JARAPP=jars/scala-benchmark-suite-0.1.0-20120216.103539-3.jar --scratch-directory $(DACAPO_SCRATCH) $(BENCH)
scala: APP=scala-$(BENCH)
scala: | $(DACAPO_SCRATCH)
scala: $(BACKEND)

runeval:
	$(MAKE) cleaneval $(foreach r,$(shell seq 1 $(times)),\
		$(foreach be,$(backends),\
			$(foreach i,$(instrs),\
				$(foreach b,$(benchs),\
					&& $(MAKE) $(SUITE) BACKEND=$(be) RUN=$(r) INSTR=$(i) BENCH=$(b) \
				)\
			)\
		)\
	)
	cat $(BUILD)/eval-runagent-*.prof > $(BUILD)/eval.$(UNAME).prof
	cat $(BUILD)/eval-runserver-*.prof >> $(BUILD)/eval.$(UNAME).prof
	cat $(BUILD)/eval-instrserver-*.prof >> $(BUILD)/eval.$(UNAME).prof
	rm $(BUILD)/eval-runagent-*.prof
	rm $(BUILD)/eval-runserver-*.prof
	rm $(BUILD)/eval-instrserver-*.prof

eval-dacapo: times=5
eval-dacapo: backends=runagent runserver
eval-dacapo: instrs=All Stats Compute Identity Empty
eval-dacapo: benchs=avrora batik eclipse fop h2 jython luindex lusearch pmd sunflow tomcat xalan
eval-dacapo: SUITE=dacapo
eval-dacapo: runeval

eval-scala: times=5
eval-scala: backends=runagent runserver
eval-scala: instrs=All Stats Compute Identity Empty
eval-scala: benchs=actors apparat dummy factorie kiama scalac scaladoc scalap scalariform scalatest scalaxb specs tmt
eval-scala: SUITE=scala
eval-scala: runeval

PROFS=$(wildcard $(BUILD)/*.prof)
PLOTDONES=$(PROFS:%=%.done)
plots: $(PLOTDONES)

$(BUILD)/%.done: $(BUILD)/% charts/charts.r
	$(R) --slave --vanilla --file=charts/charts.r --args $<
	touch $@

PDFS=$(wildcard $(BUILD)/*.pdf)
EPDFS=$(PDFS:%.pdf=%-embed.pdf)

embed: $(EPDFS)

$(BUILD)/%-embed.pdf: $(BUILD)/%.pdf charts/charts.r
	gs -dCompatibilityLevel=1.4 -dPDFSETTINGS=/screen -dSubsetFonts=true -dNOPAUSE -dBATCH -sDEVICE=pdfwrite -sOutputFile=$@ -c ".setpdfwrite <</NeverEmbed [ ]>> setdistillerparams" -f $<

docs:
	doxygen

#dots:
# DOTS=$(shell find build -name *.dot)
#dots:
PNGS=$(DOTS:%.dot=%.png)
dots: $(PNGS)

scp: scp-steklov scp-w620

scp-steklov:
	scp steklov:work/jnif/build/eval.Linux.prof build/eval.Linux.steklov.prof

scp-w620:
	scp w620:work/jnif/build/eval.Linux.prof build/eval.Linux.w620.prof

$(BUILD)/%.png: $(BUILD)/%.dot
	-dot -Tpng $< > $@

run: $(BACKEND)

eclipse:
	$(ECLIPSE_HOME)/eclipse -vmargs $(JVMARGS)

jruby:
	java -Djruby.compile.invokedynamic=true $(JVMARGS) -jar jars/jruby-mvm.jar

clean:
	rm -rf $(BUILD)

cleaneval:
	rm -rf $(BUILD)/eval-*.prof $(BUILD)/run
