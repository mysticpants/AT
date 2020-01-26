# Squirrel stuff first
INPREFIX=
OUTDIR=builds
OUTPREFIX=
TEST_DEVICE_GROUP='80920797-52eb-b253-9325-4404025cbf10'

default: buildandupload

# Device output file
$(OUTDIR)/$(OUTPREFIX)device.nut: device

# Agent output file
$(OUTDIR)/$(OUTPREFIX)agent.nut: agent

# Build device code
device:
	mkdir -p $(OUTDIR)
	pleasebuild $(INPREFIX)device.nut > $(OUTDIR)/$(OUTPREFIX)device.nut

# Build agent code
agent:
	mkdir -p $(OUTDIR)
	pleasebuild $(INPREFIX)agent.nut > $(OUTDIR)/$(OUTPREFIX)agent.nut

# Build code
build: device agent

# Upload code
upload: builds/device.nut builds/agent.nut
	impt build run

# Build and upload code, the default
buildandupload: build upload

.impt.test:
	impt test create --dg $(TEST_DEVICE_GROUP) --device-file $(OUTDIR)/$(OUTPREFIX)device.nut --agent-file $(OUTDIR)/$(OUTPREFIX)agent.nut --confirmed

testconfig: .impt.test

test: build .impt.test
	impt test run

clean:
	rm $(OUTDIR)/$(OUTPREFIX){device,agent}.nut

FORCE:
