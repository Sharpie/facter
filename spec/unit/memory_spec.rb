#!/usr/bin/env rspec

require 'spec_helper'

describe "Memory facts" do
  before do
    # We need these facts loaded, but they belong to a file with a
    # different name, so load the file explicitly.
    Facter.collection.loader.load(:memory)
  end

  after do
    Facter.clear
  end

  it "should return the current swap size" do

    Facter.fact(:kernel).stubs(:value).returns("Darwin")
    Facter::Util::Resolution.stubs(:exec).with('sysctl vm.swapusage').returns("vm.swapusage: total = 64.00M  used = 0.00M  free = 64.00M  (encrypted)")
    swapusage = "vm.swapusage: total = 64.00M  used = 0.00M  free = 64.00M  (encrypted)"

    if swapusage =~ /total = (\S+).*/
      Facter.fact(:swapfree).value.should == $1
    end
  end

  it "should return the current swap free" do
    Facter.fact(:kernel).stubs(:value).returns("Darwin")
    Facter::Util::Resolution.stubs(:exec).with('sysctl vm.swapusage').returns("vm.swapusage: total = 64.00M  used = 0.00M  free = 64.00M  (encrypted)")
    swapusage = "vm.swapusage: total = 64.00M  used = 0.00M  free = 64.00M  (encrypted)"

    if swapusage =~ /free = (\S+).*/
      Facter.fact(:swapfree).value.should == $1
    end
  end

  it "should return whether swap is encrypted" do
    Facter.fact(:kernel).stubs(:value).returns("Darwin")
    Facter::Util::Resolution.stubs(:exec).with('sysctl vm.swapusage').returns("vm.swapusage: total = 64.00M  used = 0.00M  free = 64.00M  (encrypted)")
    swapusage = "vm.swapusage: total = 64.00M  used = 0.00M  free = 64.00M  (encrypted)"

    swapusage =~ /\(encrypted\)/
    Facter.fact(:swapencrypted).value.should == true
  end

  describe "on OpenBSD" do
    before :each do
      Facter.clear
      Facter.fact(:kernel).stubs(:value).returns("OpenBSD")

      swapusage = "total: 148342k bytes allocated = 0k used, 148342k available"
      Facter::Util::Resolution.stubs(:exec).with('swapctl -s').returns(swapusage)

      vmstat = <<EOS
 procs  memory     page          disks  traps      cpu
 r b w  avm   fre  flt  re  pi  po  fr  sr cd0 sd0  int   sys   cs us sy id
 0 0 0  11048  181028   39   0   0   0   0   0   0   1  3  90   17  0  0 100
EOS
      Facter::Util::Resolution.stubs(:exec).with('vmstat').returns(vmstat)

      Facter::Util::Resolution.stubs(:exec).with("sysctl hw.physmem | cut -d'=' -f2").returns('267321344')

      Facter.collection.loader.load(:memory)
    end

    after :each do
      Facter.clear
    end

    it "should return the current swap free" do
      Facter.fact(:swapfree).value.should == "144.87 MB"
    end

    it "should return the current swap size" do
      Facter.fact(:swapsize).value.should == "144.87 MB"
    end

    it "should return the current memorysize" do
      Facter.fact(:memorysize).value.should == "254.94 MB"
    end
  end
  
  describe "on Solaris" do
    before(:each) do
      Facter.clear
      Facter.fact(:kernel).stubs(:value).returns("SunOS")
      
      Facter::Util::Resolution.stubs(:exec).with('/usr/sbin/prtconf 2>/dev/null').returns('Memory size: 1234 Megabytes')
      
      vmstat_lines = "blah blah blah\n 1 2 3 4 567890"
      Facter::Util::Resolution.stubs(:exec).with('vmstat').returns(vmstat_lines)
    end
    
    after(:each) do
      Facter.clear
    end    
    
    describe "when single swap exists" do
      before(:each) do
        expected_size = "2345"
        expected_free = "1234"
        sample_swap_line = "/blah blah #{expected_size} #{expected_free}"
        Facter::Util::Resolution.stubs(:exec).with('/usr/sbin/swap -l').returns sample_swap_line

        Facter.collection.loader.load(:memory)
      end

      it "should return the current memory size" do      
        Facter.fact(:memorysize).value.should == "1.21 GB"
      end
      
      it "should return the current memory free" do
        Facter.fact(:memoryfree).value.should == "554.58 MB"
      end
      
      it "should return the current swap free" do
        Facter.fact(:swapfree).value.should == "617.00 kB"
      end
      
      it "should return the current swap size" do
        Facter.fact(:swapsize).value.should == "1.14 MB"
      end
    end

    describe "when multiple swaps exist" do
      before(:each) do
        expected_size = "2345"
        expected_free = "1234"
        sample_swap_line = "/blah blah #{expected_size} #{expected_free}"
        Facter::Util::Resolution.stubs(:exec).with('/usr/sbin/swap -l').returns "#{sample_swap_line}\n#{sample_swap_line}"

        Facter.collection.loader.load(:memory)
      end
      
      it "should return the current memory size" do      
        Facter.fact(:memorysize).value.should == "1.21 GB"
      end
      
      it "should return the current memory free" do
        Facter.fact(:memoryfree).value.should == "554.58 MB"
      end
      
      it "should total the swap free" do
        Facter.fact(:swapfree).value.should == "1.21 MB"
      end
      
      it "should total the swap size" do
        Facter.fact(:swapsize).value.should == "2.29 MB"
      end
    end
    
    describe "when no swap exists" do
      before(:each) do
        Facter::Util::Resolution.stubs(:exec).with('/usr/sbin/swap -l').returns ""

        Facter.collection.loader.load(:memory)
      end
      
      it "should return the current memory size" do      
        Facter.fact(:memorysize).value.should == "1.21 GB"
      end
      
      it "should return the current memory free" do
        Facter.fact(:memoryfree).value.should == "554.58 MB"
      end
      
      it "should return 0 for the swap free" do
        Facter.fact(:swapfree).value.should == "0.00 kB"
      end
      
      it "should return 0 for the swap size" do
        Facter.fact(:swapsize).value.should == "0.00 kB"
      end
    end
  end

  describe "on DragonFly BSD" do
    before :each do
      Facter.clear
      Facter.fact(:kernel).stubs(:value).returns("dragonfly")

      swapusage = "total: 148342k bytes allocated = 0k used, 148342k available"
      Facter::Util::Resolution.stubs(:exec).with('/sbin/sysctl -n hw.pagesize').returns("4096")
      Facter::Util::Resolution.stubs(:exec).with('/sbin/sysctl -n vm.swap_size').returns("128461")
      Facter::Util::Resolution.stubs(:exec).with('/sbin/sysctl -n vm.swap_anon_use').returns("2635")
      Facter::Util::Resolution.stubs(:exec).with('/sbin/sysctl -n vm.swap_cache_use').returns("0")

      vmstat = <<EOS
 procs    memory    page          disks   faults    cpu
 r b w   avm  fre  flt  re  pi  po  fr  sr da0 sg1   in   sy  cs us sy id
 0 0 0   33152  13940 1902120 2198 53119 11642 6544597 5460994   0   0 6148243 7087927 3484264  0  1 9
EOS
      Facter::Util::Resolution.stubs(:exec).with('vmstat').returns(vmstat)

      Facter::Util::Resolution.stubs(:exec).with("sysctl -n hw.physmem").returns('248512512')

      Facter.collection.loader.load(:memory)
    end

    after :each do
      Facter.clear
    end

    it "should return the current swap free" do
      Facter.fact(:swapfree).value.should == "491.51 MB"
    end

    it "should return the current swap size" do
      Facter.fact(:swapsize).value.should == "501.80 MB"
    end

    it "should return the current memorysize" do
      Facter.fact(:memorysize).value.should == "237.00 MB"
    end
  end

  describe "on Windows" do
    before :each do
      Facter.clear
      Facter.fact(:kernel).stubs(:value).returns("windows")
      Facter.collection.loader.load(:memory)

      require 'facter/util/wmi'
    end

    it "should return free memory" do
      os = stubs 'os'
      os.stubs(:FreePhysicalMemory).returns("3415624")
      Facter::Util::WMI.stubs(:execquery).returns([os])

      Facter.fact(:MemoryFree).value.should == '3.26 GB'
    end

    it "should return total memory" do
      computer = stubs 'computer'
      computer.stubs(:TotalPhysicalMemory).returns("4193837056")
      Facter::Util::WMI.stubs(:execquery).returns([computer])

      Facter.fact(:MemorySize).value.should == '3.91 GB'
    end
  end
end
