# You shouldn't need to tweak the following variable definitions.

# Points to the root of Google Test, relative to where this file is.
# Remember to tweak this if you move this file.
GTEST_DIR = $(HOME)/googletest/googletest

# Where to find user code.
USER_DIR = src

# The c++ compiler to use
CXX = /usr/bin/clang++-3.8

# Flags passed to the preprocessor.
# Set Google Test's header directory as a system directory, such that
# the compiler doesn't generate warnings in Google Test headers.
CPPFLAGS += -isystem $(GTEST_DIR)/include

# Flags passed to the C++ compiler.
CXXFLAGS += -g -Wall -Wextra -pthread -std=c++11 

CXXFLAGS_COVERAGE = -fno-sanitize=address -fprofile-instr-generate -fcoverage-mapping

# All Google Test headers.  Usually you shouldn't change this
# definition.
GTEST_HEADERS = $(GTEST_DIR)/include/gtest/*.h \
				$(GTEST_DIR)/include/gtest/internal/*.h

OBJDIR := build
COVDIR := coverage
# House-keeping build targets.

# Default build target. This must come first
.PHONY: all clean
all : $(addprefix $(OBJDIR)/, $(TESTS))

clean :
	rm -rf build
	rm -rf coverage

$(OBJDIR):
	mkdir $(OBJDIR)
$(COVDIR):
	mkdir $(COVDIR)

$(GTEST_DIR):
	sudo apt-get -y -qq update
	sudo apt-get -y -qq install git clang-3.8 npm
	sudo npm install -g -q ansi-to-html
	cd $(HOME);git clone https://github.com/google/googletest.git

# Builds gtest.a and gtest_main.a.

# Usually you shouldn't tweak such internal variables, indicated by a
# trailing _.
GTEST_SRCS_ = $(GTEST_DIR)/src/*.cc $(GTEST_DIR)/src/*.h $(GTEST_HEADERS)

# For simplicity and to avoid depending on Google Test's
# implementation details, the dependencies specified below are
# conservative and not optimized.  This is fine as Google Test
# compiles fast and for ordinary users its source rarely changes.
$(OBJDIR)/gtest-all.o : $(GTEST_SRCS_) | $(OBJDIR) $(GTEST_DIR)
	$(CXX) $(CPPFLAGS) -I$(GTEST_DIR) $(CXXFLAGS) -c \
			$(GTEST_DIR)/src/gtest-all.cc -o $@

$(OBJDIR)/gtest_main.o : $(GTEST_SRCS_) | $(OBJDIR) $(GTEST_DIR)
	$(CXX) $(CPPFLAGS) -I$(GTEST_DIR) $(CXXFLAGS) -c \
			$(GTEST_DIR)/src/gtest_main.cc -o $@

$(OBJDIR)/gtest.a : $(OBJDIR)/gtest-all.o
	$(AR) $(ARFLAGS) $@ $^

$(OBJDIR)/gtest_main.a : $(OBJDIR)/gtest-all.o $(OBJDIR)/gtest_main.o
	$(AR) $(ARFLAGS) $@ $^

$(OBJDIR)/%.d: $(USER_DIR)/%.cpp | $(OBJDIR) $(GTEST_DIR)
		@set -e; rm -f $@; \
		 $(CXX) -MM $(CPPFLAGS) $(CXXFLAGS) $< > $@.$$$$; \
		 sed 's,\($*\)\.o[ :]*,$(OBJDIR)/\1.o $@ : ,g' < $@.$$$$ > $@; \
		 rm -f $@.$$$$

define TEST_template
$$(OBJDIR)/$(1): $$(addprefix $$(OBJDIR)/,$$($(1)_SRCS:.cpp=.o))
	$$(CXX) $$(CPPFLAGS) $$(CXXFLAGS) -lpthread $$^ -o $$@
$$(OBJDIR)/$(1).cov: $$(addprefix $$(OBJDIR)/,$$($(1)_SRCS:.cpp=.cov.o)) | $$(COVDIR)
	$$(CXX) $$(CPPFLAGS) $$(CXXFLAGS) $$(CXXFLAGS_COVERAGE) -lpthread $$^ -o $$@
	echo $$(addprefix $$(USER_DIR)/,$$(filter %.cpp,$$($(1)_SRCS))) >$$@.sources
ALL_SRCS   += $$($(1)_SRCS)
$$(OBJDIR)/$(1): CXXFLAGS +=  -fsanitize=address
$$(filter %.o,$$(addprefix $$(OBJDIR)/,$$($(1)_SRCS:.cpp=.o))): CXXFLAGS +=  -fsanitize=address
endef

$(foreach prog,$(TESTS),$(eval $(call TEST_template,$(prog))))


-include $(filter %.d,$(addprefix $(OBJDIR)/,$(ALL_SRCS:.cpp=.d)))

# Builds a sample test.  A test should link with either gtest.a or
# gtest_main.a, depending on whether it defines its own main()
# function.

$(OBJDIR)/%.o : $(USER_DIR)/%.cpp | $(OBJDIR) $(GTEST_DIR)
	$(CXX) $(CPPFLAGS) $(CXXFLAGS) -c $< -o $@

$(OBJDIR)/%.cov.o : $(USER_DIR)/%.cpp $(OBJDIR)/%.o
	$(CXX) $(CPPFLAGS) $(CXXFLAGS) $(CXXFLAGS_COVERAGE) -c $< -o $@


