local P = {}

function P.getPinSettings(pin)
	pin_map = {
      GPIO_0_GPIO0                    = 0x00060000,
      GPIO_0_EPWM1A                   = 0x00060001,
      GPIO_0_SDAA                     = 0x00060006,

      GPIO_1_GPIO1                    = 0x00060200,
      GPIO_1_EPWM1B                   = 0x00060201,
      GPIO_1_MFSRB                    = 0x00060203,
      GPIO_1_SCLA                     = 0x00060206,

      GPIO_2_GPIO2                    = 0x00060400,
      GPIO_2_EPWM2A                   = 0x00060401,
      GPIO_2_OUTPUTXBAR1              = 0x00060405,
      GPIO_2_SDAB                     = 0x00060406,

      GPIO_3_GPIO3                    = 0x00060600,
      GPIO_3_EPWM2B                   = 0x00060601,
      GPIO_3_OUTPUTXBAR2              = 0x00060602,
      GPIO_3_MCLKRB                   = 0x00060603,
      GPIO_3_SCLB                     = 0x00060606,

      GPIO_4_GPIO4                    = 0x00060800,
      GPIO_4_EPWM3A                   = 0x00060801,
      GPIO_4_OUTPUTXBAR3              = 0x00060805,
      GPIO_4_CANTXA                   = 0x00060806,

      GPIO_5_GPIO5                    = 0x00060A00,
      GPIO_5_EPWM3B                   = 0x00060A01,
      GPIO_5_MFSRA                    = 0x00060A02,
      GPIO_5_OUTPUTXBAR3              = 0x00060A03,
      GPIO_5_CANRXA                   = 0x00060A06,

      GPIO_6_GPIO6                    = 0x00060C00,
      GPIO_6_EPWM4A                   = 0x00060C01,
      GPIO_6_OUTPUTXBAR4              = 0x00060C02,
      GPIO_6_EPWMSYNCO                = 0x00060C03,
      GPIO_6_EQEP3A                   = 0x00060C05,
      GPIO_6_CANTXB                   = 0x00060C06,

      GPIO_7_GPIO7                    = 0x00060E00,
      GPIO_7_EPWM4B                   = 0x00060E01,
      GPIO_7_MCLKRA                   = 0x00060E02,
      GPIO_7_OUTPUTXBAR5              = 0x00060E03,
      GPIO_7_EQEP3B                   = 0x00060E05,
      GPIO_7_CANRXB                   = 0x00060E06,

      GPIO_8_GPIO8                    = 0x00061000,
      GPIO_8_EPWM5A                   = 0x00061001,
      GPIO_8_CANTXB                   = 0x00061002,
      GPIO_8_ADCSOCAO                 = 0x00061003,
      GPIO_8_EQEP3S                   = 0x00061005,
      GPIO_8_SCITXDA                  = 0x00061006,

      GPIO_9_GPIO9                    = 0x00061200,
      GPIO_9_EPWM5B                   = 0x00061201,
      GPIO_9_SCITXDB                  = 0x00061202,
      GPIO_9_OUTPUTXBAR6              = 0x00061203,
      GPIO_9_EQEP3I                   = 0x00061205,
      GPIO_9_SCIRXDA                  = 0x00061206,

      GPIO_10_GPIO10                  = 0x00061400,
      GPIO_10_EPWM6A                  = 0x00061401,
      GPIO_10_CANRXB                  = 0x00061402,
      GPIO_10_ADCSOCBO                = 0x00061403,
      GPIO_10_EQEP1A                  = 0x00061405,
      GPIO_10_SCITXDB                 = 0x00061406,
      GPIO_10_UPP_WAIT                = 0x0006140F,

      GPIO_11_GPIO11                  = 0x00061600,
      GPIO_11_EPWM6B                  = 0x00061601,
      GPIO_11_SCIRXDB                 = 0x00061602,
      GPIO_11_OUTPUTXBAR7             = 0x00061603,
      GPIO_11_EQEP1B                  = 0x00061605,
      GPIO_11_UPP_STRT                = 0x0006160F,

      GPIO_12_GPIO12                  = 0x00061800,
      GPIO_12_EPWM7A                  = 0x00061801,
      GPIO_12_CANTXB                  = 0x00061802,
      GPIO_12_MDXB                    = 0x00061803,
      GPIO_12_EQEP1S                  = 0x00061805,
      GPIO_12_SCITXDC                 = 0x00061806,
      GPIO_12_UPP_ENA                 = 0x0006180F,

      GPIO_13_GPIO13                  = 0x00061A00,
      GPIO_13_EPWM7B                  = 0x00061A01,
      GPIO_13_CANRXB                  = 0x00061A02,
      GPIO_13_MDRB                    = 0x00061A03,
      GPIO_13_EQEP1I                  = 0x00061A05,
      GPIO_13_SCIRXDC                 = 0x00061A06,
      GPIO_13_UPP_D7                  = 0x00061A0F,

      GPIO_14_GPIO14                  = 0x00061C00,
      GPIO_14_EPWM8A                  = 0x00061C01,
      GPIO_14_SCITXDB                 = 0x00061C02,
      GPIO_14_MCLKXB                  = 0x00061C03,
      GPIO_14_OUTPUTXBAR3             = 0x00061C06,
      GPIO_14_UPP_D6                  = 0x00061C0F,

      GPIO_15_GPIO15                  = 0x00061E00,
      GPIO_15_EPWM8B                  = 0x00061E01,
      GPIO_15_SCIRXDB                 = 0x00061E02,
      GPIO_15_MFSXB                   = 0x00061E03,
      GPIO_15_OUTPUTXBAR4             = 0x00061E06,
      GPIO_15_UPP_D5                  = 0x00061E0F,

      GPIO_16_GPIO16                  = 0x00080000,
      GPIO_16_SPISIMOA                = 0x00080001,
      GPIO_16_CANTXB                  = 0x00080002,
      GPIO_16_OUTPUTXBAR7             = 0x00080003,
      GPIO_16_EPWM9A                  = 0x00080005,
      GPIO_16_SD1_D1                  = 0x00080007,
      GPIO_16_UPP_D4                  = 0x0008000F,

      GPIO_17_GPIO17                  = 0x00080200,
      GPIO_17_SPISOMIA                = 0x00080201,
      GPIO_17_CANRXB                  = 0x00080202,
      GPIO_17_OUTPUTXBAR8             = 0x00080203,
      GPIO_17_EPWM9B                  = 0x00080205,
      GPIO_17_SD1_C1                  = 0x00080207,
      GPIO_17_UPP_D3                  = 0x0008020F,

      GPIO_18_GPIO18                  = 0x00080400,
      GPIO_18_SPICLKA                 = 0x00080401,
      GPIO_18_SCITXDB                 = 0x00080402,
      GPIO_18_CANRXA                  = 0x00080403,
      GPIO_18_EPWM10A                 = 0x00080405,
      GPIO_18_SD1_D2                  = 0x00080407,
      GPIO_18_UPP_D2                  = 0x0008040F,

      GPIO_19_GPIO19                  = 0x00080600,
      GPIO_19_SPISTEA                 = 0x00080601,
      GPIO_19_SCIRXDB                 = 0x00080602,
      GPIO_19_CANTXA                  = 0x00080603,
      GPIO_19_EPWM10B                 = 0x00080605,
      GPIO_19_SD1_C2                  = 0x00080607,
      GPIO_19_UPP_D1                  = 0x0008060F,

      GPIO_20_GPIO20                  = 0x00080800,
      GPIO_20_EQEP1A                  = 0x00080801,
      GPIO_20_MDXA                    = 0x00080802,
      GPIO_20_CANTXB                  = 0x00080803,
      GPIO_20_EPWM11A                 = 0x00080805,
      GPIO_20_SD1_D3                  = 0x00080807,
      GPIO_20_UPP_D0                  = 0x0008080F,

      GPIO_21_GPIO21                  = 0x00080A00,
      GPIO_21_EQEP1B                  = 0x00080A01,
      GPIO_21_MDRA                    = 0x00080A02,
      GPIO_21_CANRXB                  = 0x00080A03,
      GPIO_21_EPWM11B                 = 0x00080A05,
      GPIO_21_SD1_C3                  = 0x00080A07,
      GPIO_21_UPP_CLK                 = 0x00080A0F,

      GPIO_22_GPIO22                  = 0x00080C00,
      GPIO_22_EQEP1S                  = 0x00080C01,
      GPIO_22_MCLKXA                  = 0x00080C02,
      GPIO_22_SCITXDB                 = 0x00080C03,
      GPIO_22_EPWM12A                 = 0x00080C05,
      GPIO_22_SPICLKB                 = 0x00080C06,
      GPIO_22_SD1_D4                  = 0x00080C07,

      GPIO_23_GPIO23                  = 0x00080E00,
      GPIO_23_EQEP1I                  = 0x00080E01,
      GPIO_23_MFSXA                   = 0x00080E02,
      GPIO_23_SCIRXDB                 = 0x00080E03,
      GPIO_23_EPWM12B                 = 0x00080E05,
      GPIO_23_SPISTEB                 = 0x00080E06,
      GPIO_23_SD1_C4                  = 0x00080E07,

      GPIO_24_GPIO24                  = 0x00081000,
      GPIO_24_OUTPUTXBAR1             = 0x00081001,
      GPIO_24_EQEP2A                  = 0x00081002,
      GPIO_24_MDXB                    = 0x00081003,
      GPIO_24_SPISIMOB                = 0x00081006,
      GPIO_24_SD2_D1                  = 0x00081007,

      GPIO_25_GPIO25                  = 0x00081200,
      GPIO_25_OUTPUTXBAR2             = 0x00081201,
      GPIO_25_EQEP2B                  = 0x00081202,
      GPIO_25_MDRB                    = 0x00081203,
      GPIO_25_SPISOMIB                = 0x00081206,
      GPIO_25_SD2_C1                  = 0x00081207,

      GPIO_26_GPIO26                  = 0x00081400,
      GPIO_26_OUTPUTXBAR3             = 0x00081401,
      GPIO_26_EQEP2I                  = 0x00081402,
      GPIO_26_MCLKXB                  = 0x00081403,
      GPIO_26_SPICLKB                 = 0x00081406,
      GPIO_26_SD2_D2                  = 0x00081407,

      GPIO_27_GPIO27                  = 0x00081600,
      GPIO_27_OUTPUTXBAR4             = 0x00081601,
      GPIO_27_EQEP2S                  = 0x00081602,
      GPIO_27_MFSXB                   = 0x00081603,
      GPIO_27_SPISTEB                 = 0x00081606,
      GPIO_27_SD2_C2                  = 0x00081607,

      GPIO_28_GPIO28                  = 0x00081800,
      GPIO_28_SCIRXDA                 = 0x00081801,
      GPIO_28_EM1CS4N                 = 0x00081802,
      GPIO_28_OUTPUTXBAR5             = 0x00081805,
      GPIO_28_EQEP3A                  = 0x00081806,
      GPIO_28_SD2_D3                  = 0x00081807,

      GPIO_29_GPIO29                  = 0x00081A00,
      GPIO_29_SCITXDA                 = 0x00081A01,
      GPIO_29_EM1SDCKE                = 0x00081A02,
      GPIO_29_OUTPUTXBAR6             = 0x00081A05,
      GPIO_29_EQEP3B                  = 0x00081A06,
      GPIO_29_SD2_C3                  = 0x00081A07,

      GPIO_30_GPIO30                  = 0x00081C00,
      GPIO_30_CANRXA                  = 0x00081C01,
      GPIO_30_EM1CLK                  = 0x00081C02,
      GPIO_30_OUTPUTXBAR7             = 0x00081C05,
      GPIO_30_EQEP3S                  = 0x00081C06,
      GPIO_30_SD2_D4                  = 0x00081C07,

      GPIO_31_GPIO31                  = 0x00081E00,
      GPIO_31_CANTXA                  = 0x00081E01,
      GPIO_31_EM1WEN                  = 0x00081E02,
      GPIO_31_OUTPUTXBAR8             = 0x00081E05,
      GPIO_31_EQEP3I                  = 0x00081E06,
      GPIO_31_SD2_C4                  = 0x00081E07,

      GPIO_32_GPIO32                  = 0x00460000,
      GPIO_32_SDAA                    = 0x00460001,
      GPIO_32_EM1CS0N                 = 0x00460002,

      GPIO_33_GPIO33                  = 0x00460200,
      GPIO_33_SCLA                    = 0x00460201,
      GPIO_33_EM1RNW                  = 0x00460202,

      GPIO_34_GPIO34                  = 0x00460400,
      GPIO_34_OUTPUTXBAR1             = 0x00460401,
      GPIO_34_EM1CS2N                 = 0x00460402,
      GPIO_34_SDAB                    = 0x00460406,
      GPIO_34_OFSD_2_N                = 0x0046040F,

      GPIO_35_GPIO35                  = 0x00460600,
      GPIO_35_SCIRXDA                 = 0x00460601,
      GPIO_35_EM1CS3N                 = 0x00460602,
      GPIO_35_SCLB                    = 0x00460606,
      GPIO_35_IID                     = 0x0046060F,

      GPIO_36_GPIO36                  = 0x00460800,
      GPIO_36_SCITXDA                 = 0x00460801,
      GPIO_36_EM1WAIT                 = 0x00460802,
      GPIO_36_CANRXA                  = 0x00460806,
      GPIO_36_ISESSEND                = 0x0046080F,

      GPIO_37_GPIO37                  = 0x00460A00,
      GPIO_37_OUTPUTXBAR2             = 0x00460A01,
      GPIO_37_EM1OEN                  = 0x00460A02,
      GPIO_37_CANTXA                  = 0x00460A06,
      GPIO_37_IAVALID                 = 0x00460A0F,

      GPIO_38_GPIO38                  = 0x00460C00,
      GPIO_38_EM1A0                   = 0x00460C02,
      GPIO_38_SCITXDC                 = 0x00460C05,
      GPIO_38_CANTXB                  = 0x00460C06,

      GPIO_39_GPIO39                  = 0x00460E00,
      GPIO_39_EM1A1                   = 0x00460E02,
      GPIO_39_SCIRXDC                 = 0x00460E05,
      GPIO_39_CANRXB                  = 0x00460E06,

      GPIO_40_GPIO40                  = 0x00461000,
      GPIO_40_EM1A2                   = 0x00461002,
      GPIO_40_SDAB                    = 0x00461006,

      GPIO_41_GPIO41                  = 0x00461200,
      GPIO_41_EM1A3                   = 0x00461202,
      GPIO_41_EMU1                    = 0x00461203,
      GPIO_41_SCLB                    = 0x00461206,

      GPIO_42_GPIO42                  = 0x00461400,
      GPIO_42_SDAA                    = 0x00461406,
      GPIO_42_SCITXDA                 = 0x0046140F,

      GPIO_43_GPIO43                  = 0x00461600,
      GPIO_43_SCLA                    = 0x00461606,
      GPIO_43_SCIRXDA                 = 0x0046160F,

      GPIO_44_GPIO44                  = 0x00461800,
      GPIO_44_EM1A4                   = 0x00461802,
      GPIO_44_IXRCV                   = 0x0046180F,

      GPIO_45_GPIO45                  = 0x00461A00,
      GPIO_45_EM1A5                   = 0x00461A02,
      GPIO_45_IDM                     = 0x00461A0F,

      GPIO_46_GPIO46                  = 0x00461C00,
      GPIO_46_EM1A6                   = 0x00461C02,
      GPIO_46_SCIRXDD                 = 0x00461C06,
      GPIO_46_IDP                     = 0x00461C0F,

      GPIO_47_GPIO47                  = 0x00461E00,
      GPIO_47_EM1A7                   = 0x00461E02,
      GPIO_47_SCITXDD                 = 0x00461E06,
      GPIO_47_OFSD_1_N                = 0x00461E0F,

      GPIO_48_GPIO48                  = 0x00480000,
      GPIO_48_OUTPUTXBAR3             = 0x00480001,
      GPIO_48_EM1A8                   = 0x00480002,
      GPIO_48_SCITXDA                 = 0x00480006,
      GPIO_48_SD1_D1                  = 0x00480007,

      GPIO_49_GPIO49                  = 0x00480200,
      GPIO_49_OUTPUTXBAR4             = 0x00480201,
      GPIO_49_EM1A9                   = 0x00480202,
      GPIO_49_SCIRXDA                 = 0x00480206,
      GPIO_49_SD1_C1                  = 0x00480207,

      GPIO_50_GPIO50                  = 0x00480400,
      GPIO_50_EQEP1A                  = 0x00480401,
      GPIO_50_EM1A10                  = 0x00480402,
      GPIO_50_SPISIMOC                = 0x00480406,
      GPIO_50_SD1_D2                  = 0x00480407,

      GPIO_51_GPIO51                  = 0x00480600,
      GPIO_51_EQEP1B                  = 0x00480601,
      GPIO_51_EM1A11                  = 0x00480602,
      GPIO_51_SPISOMIC                = 0x00480606,
      GPIO_51_SD1_C2                  = 0x00480607,

      GPIO_52_GPIO52                  = 0x00480800,
      GPIO_52_EQEP1S                  = 0x00480801,
      GPIO_52_EM1A12                  = 0x00480802,
      GPIO_52_SPICLKC                 = 0x00480806,
      GPIO_52_SD1_D3                  = 0x00480807,

      GPIO_53_GPIO53                  = 0x00480A00,
      GPIO_53_EQEP1I                  = 0x00480A01,
      GPIO_53_EM1D31                  = 0x00480A02,
      GPIO_53_EM2D15                  = 0x00480A03,
      GPIO_53_SPISTEC                 = 0x00480A06,
      GPIO_53_SD1_C3                  = 0x00480A07,

      GPIO_54_GPIO54                  = 0x00480C00,
      GPIO_54_SPISIMOA                = 0x00480C01,
      GPIO_54_EM1D30                  = 0x00480C02,
      GPIO_54_EM2D14                  = 0x00480C03,
      GPIO_54_EQEP2A                  = 0x00480C05,
      GPIO_54_SCITXDB                 = 0x00480C06,
      GPIO_54_SD1_D4                  = 0x00480C07,

      GPIO_55_GPIO55                  = 0x00480E00,
      GPIO_55_SPISOMIA                = 0x00480E01,
      GPIO_55_EM1D29                  = 0x00480E02,
      GPIO_55_EM2D13                  = 0x00480E03,
      GPIO_55_EQEP2B                  = 0x00480E05,
      GPIO_55_SCIRXDB                 = 0x00480E06,
      GPIO_55_SD1_C4                  = 0x00480E07,

      GPIO_56_GPIO56                  = 0x00481000,
      GPIO_56_SPICLKA                 = 0x00481001,
      GPIO_56_EM1D28                  = 0x00481002,
      GPIO_56_EM2D12                  = 0x00481003,
      GPIO_56_EQEP2S                  = 0x00481005,
      GPIO_56_SCITXDC                 = 0x00481006,
      GPIO_56_SD2_D1                  = 0x00481007,

      GPIO_57_GPIO57                  = 0x00481200,
      GPIO_57_SPISTEA                 = 0x00481201,
      GPIO_57_EM1D27                  = 0x00481202,
      GPIO_57_EM2D11                  = 0x00481203,
      GPIO_57_EQEP2I                  = 0x00481205,
      GPIO_57_SCIRXDC                 = 0x00481206,
      GPIO_57_SD2_C1                  = 0x00481207,

      GPIO_58_GPIO58                  = 0x00481400,
      GPIO_58_MCLKRA                  = 0x00481401,
      GPIO_58_EM1D26                  = 0x00481402,
      GPIO_58_EM2D10                  = 0x00481403,
      GPIO_58_OUTPUTXBAR1             = 0x00481405,
      GPIO_58_SPICLKB                 = 0x00481406,
      GPIO_58_SD2_D2                  = 0x00481407,
      GPIO_58_SPISIMOA                = 0x0048140F,

      GPIO_59_GPIO59                  = 0x00481600,
      GPIO_59_MFSRA                   = 0x00481601,
      GPIO_59_EM1D25                  = 0x00481602,
      GPIO_59_EM2D9                   = 0x00481603,
      GPIO_59_OUTPUTXBAR2             = 0x00481605,
      GPIO_59_SPISTEB                 = 0x00481606,
      GPIO_59_SD2_C2                  = 0x00481607,
      GPIO_59_SPISOMIA                = 0x0048160F,

      GPIO_60_GPIO60                  = 0x00481800,
      GPIO_60_MCLKRB                  = 0x00481801,
      GPIO_60_EM1D24                  = 0x00481802,
      GPIO_60_EM2D8                   = 0x00481803,
      GPIO_60_OUTPUTXBAR3             = 0x00481805,
      GPIO_60_SPISIMOB                = 0x00481806,
      GPIO_60_SD2_D3                  = 0x00481807,
      GPIO_60_SPICLKA                 = 0x0048180F,

      GPIO_61_GPIO61                  = 0x00481A00,
      GPIO_61_MFSRB                   = 0x00481A01,
      GPIO_61_EM1D23                  = 0x00481A02,
      GPIO_61_EM2D7                   = 0x00481A03,
      GPIO_61_OUTPUTXBAR4             = 0x00481A05,
      GPIO_61_SPISOMIB                = 0x00481A06,
      GPIO_61_SD2_C3                  = 0x00481A07,
      GPIO_61_SPISTEA                 = 0x00481A0F,

      GPIO_62_GPIO62                  = 0x00481C00,
      GPIO_62_SCIRXDC                 = 0x00481C01,
      GPIO_62_EM1D22                  = 0x00481C02,
      GPIO_62_EM2D6                   = 0x00481C03,
      GPIO_62_EQEP3A                  = 0x00481C05,
      GPIO_62_CANRXA                  = 0x00481C06,
      GPIO_62_SD2_D4                  = 0x00481C07,

      GPIO_63_GPIO63                  = 0x00481E00,
      GPIO_63_SCITXDC                 = 0x00481E01,
      GPIO_63_EM1D21                  = 0x00481E02,
      GPIO_63_EM2D5                   = 0x00481E03,
      GPIO_63_EQEP3B                  = 0x00481E05,
      GPIO_63_CANTXA                  = 0x00481E06,
      GPIO_63_SD2_C4                  = 0x00481E07,
      GPIO_63_SPISIMOB                = 0x00481E0F,

      GPIO_64_GPIO64                  = 0x00860000,
      GPIO_64_EM1D20                  = 0x00860002,
      GPIO_64_EM2D4                   = 0x00860003,
      GPIO_64_EQEP3S                  = 0x00860005,
      GPIO_64_SCIRXDA                 = 0x00860006,
      GPIO_64_SPISOMIB                = 0x0086000F,

      GPIO_65_GPIO65                  = 0x00860200,
      GPIO_65_EM1D19                  = 0x00860202,
      GPIO_65_EM2D3                   = 0x00860203,
      GPIO_65_EQEP3I                  = 0x00860205,
      GPIO_65_SCITXDA                 = 0x00860206,
      GPIO_65_SPICLKB                 = 0x0086020F,

      GPIO_66_GPIO66                  = 0x00860400,
      GPIO_66_EM1D18                  = 0x00860402,
      GPIO_66_EM2D2                   = 0x00860403,
      GPIO_66_SDAB                    = 0x00860406,
      GPIO_66_SPISTEB                 = 0x0086040F,

      GPIO_67_GPIO67                  = 0x00860600,
      GPIO_67_EM1D17                  = 0x00860602,
      GPIO_67_EM2D1                   = 0x00860603,

      GPIO_68_GPIO68                  = 0x00860800,
      GPIO_68_EM1D16                  = 0x00860802,
      GPIO_68_EM2D0                   = 0x00860803,

      GPIO_69_GPIO69                  = 0x00860A00,
      GPIO_69_EM1D15                  = 0x00860A02,
      GPIO_69_EMU0                    = 0x00860A03,
      GPIO_69_SCLB                    = 0x00860A06,
      GPIO_69_SPISIMOC                = 0x00860A0F,

      GPIO_70_GPIO70                  = 0x00860C00,
      GPIO_70_EM1D14                  = 0x00860C02,
      GPIO_70_EMU0                    = 0x00860C03,
      GPIO_70_CANRXA                  = 0x00860C05,
      GPIO_70_SCITXDB                 = 0x00860C06,
      GPIO_70_SPISOMIC                = 0x00860C0F,

      GPIO_71_GPIO71                  = 0x00860E00,
      GPIO_71_EM1D13                  = 0x00860E02,
      GPIO_71_EMU1                    = 0x00860E03,
      GPIO_71_CANTXA                  = 0x00860E05,
      GPIO_71_SCIRXDB                 = 0x00860E06,
      GPIO_71_SPICLKC                 = 0x00860E0F,

      GPIO_72_GPIO72                  = 0x00861000,
      GPIO_72_EM1D12                  = 0x00861002,
      GPIO_72_CANTXB                  = 0x00861005,
      GPIO_72_SCITXDC                 = 0x00861006,
      GPIO_72_SPISTEC                 = 0x0086100F,

      GPIO_73_GPIO73                  = 0x00861200,
      GPIO_73_EM1D11                  = 0x00861202,
      GPIO_73_XCLKOUT                 = 0x00861203,
      GPIO_73_CANRXB                  = 0x00861205,
      GPIO_73_SCIRXDC                 = 0x00861206,

      GPIO_74_GPIO74                  = 0x00861400,
      GPIO_74_EM1D10                  = 0x00861402,

      GPIO_75_GPIO75                  = 0x00861600,
      GPIO_75_EM1D9                   = 0x00861602,

      GPIO_76_GPIO76                  = 0x00861800,
      GPIO_76_EM1D8                   = 0x00861802,
      GPIO_76_SCITXDD                 = 0x00861806,

      GPIO_77_GPIO77                  = 0x00861A00,
      GPIO_77_EM1D7                   = 0x00861A02,
      GPIO_77_SCIRXDD                 = 0x00861A06,

      GPIO_78_GPIO78                  = 0x00861C00,
      GPIO_78_EM1D6                   = 0x00861C02,
      GPIO_78_EQEP2A                  = 0x00861C06,

      GPIO_79_GPIO79                  = 0x00861E00,
      GPIO_79_EM1D5                   = 0x00861E02,
      GPIO_79_EQEP2B                  = 0x00861E06,

      GPIO_80_GPIO80                  = 0x00880000,
      GPIO_80_EM1D4                   = 0x00880002,
      GPIO_80_EQEP2S                  = 0x00880006,

      GPIO_81_GPIO81                  = 0x00880200,
      GPIO_81_EM1D3                   = 0x00880202,
      GPIO_81_EQEP2I                  = 0x00880206,

      GPIO_82_GPIO82                  = 0x00880400,
      GPIO_82_EM1D2                   = 0x00880402,

      GPIO_83_GPIO83                  = 0x00880600,
      GPIO_83_EM1D1                   = 0x00880602,

      GPIO_84_GPIO84                  = 0x00880800,
      GPIO_84_SCITXDA                 = 0x00880805,
      GPIO_84_MDXB                    = 0x00880806,
      GPIO_84_MDXA                    = 0x0088080F,

      GPIO_85_GPIO85                  = 0x00880A00,
      GPIO_85_EM1D0                   = 0x00880A02,
      GPIO_85_SCIRXDA                 = 0x00880A05,
      GPIO_85_MDRB                    = 0x00880A06,
      GPIO_85_MDRA                    = 0x00880A0F,

      GPIO_86_GPIO86                  = 0x00880C00,
      GPIO_86_EM1A13                  = 0x00880C02,
      GPIO_86_EM1CAS                  = 0x00880C03,
      GPIO_86_SCITXDB                 = 0x00880C05,
      GPIO_86_MCLKXB                  = 0x00880C06,
      GPIO_86_MCLKXA                  = 0x00880C0F,

      GPIO_87_GPIO87                  = 0x00880E00,
      GPIO_87_EM1A14                  = 0x00880E02,
      GPIO_87_EM1RAS                  = 0x00880E03,
      GPIO_87_SCIRXDB                 = 0x00880E05,
      GPIO_87_MFSXB                   = 0x00880E06,
      GPIO_87_MFSXA                   = 0x00880E0F,

      GPIO_88_GPIO88                  = 0x00881000,
      GPIO_88_EM1A15                  = 0x00881002,
      GPIO_88_EM1DQM0                 = 0x00881003,

      GPIO_89_GPIO89                  = 0x00881200,
      GPIO_89_EM1A16                  = 0x00881202,
      GPIO_89_EM1DQM1                 = 0x00881203,
      GPIO_89_SCITXDC                 = 0x00881206,

      GPIO_90_GPIO90                  = 0x00881400,
      GPIO_90_EM1A17                  = 0x00881402,
      GPIO_90_EM1DQM2                 = 0x00881403,
      GPIO_90_SCIRXDC                 = 0x00881406,

      GPIO_91_GPIO91                  = 0x00881600,
      GPIO_91_EM1A18                  = 0x00881602,
      GPIO_91_EM1DQM3                 = 0x00881603,
      GPIO_91_SDAA                    = 0x00881606,

      GPIO_92_GPIO92                  = 0x00881800,
      GPIO_92_EM1A19                  = 0x00881802,
      GPIO_92_EM1BA1                  = 0x00881803,
      GPIO_92_SCLA                    = 0x00881806,

      GPIO_93_GPIO93                  = 0x00881A00,
      GPIO_93_EM1A20                  = 0x00881A02,
      GPIO_93_EM1BA0                  = 0x00881A03,
      GPIO_93_SCITXDD                 = 0x00881A06,

      GPIO_94_GPIO94                  = 0x00881C00,
      GPIO_94_EM1A21                  = 0x00881C02,
      GPIO_94_SCIRXDD                 = 0x00881C06,

      GPIO_95_GPIO95                  = 0x00881E00,

      GPIO_96_GPIO96                  = 0x00C60000,
      GPIO_96_EM2DQM1                 = 0x00C60003,
      GPIO_96_EQEP1A                  = 0x00C60005,

      GPIO_97_GPIO97                  = 0x00C60200,
      GPIO_97_EM2DQM0                 = 0x00C60203,
      GPIO_97_EQEP1B                  = 0x00C60205,

      GPIO_98_GPIO98                  = 0x00C60400,
      GPIO_98_EM2A0                   = 0x00C60403,
      GPIO_98_EQEP1S                  = 0x00C60405,

      GPIO_99_GPIO99                  = 0x00C60600,
      GPIO_99_EM2A1                   = 0x00C60603,
      GPIO_99_EQEP1I                  = 0x00C60605,

      GPIO_100_GPIO100                = 0x00C60800,
      GPIO_100_EM2A2                  = 0x00C60803,
      GPIO_100_EQEP2A                 = 0x00C60805,
      GPIO_100_SPISIMOC               = 0x00C60806,

      GPIO_101_GPIO101                = 0x00C60A00,
      GPIO_101_EM2A3                  = 0x00C60A03,
      GPIO_101_EQEP2B                 = 0x00C60A05,
      GPIO_101_SPISOMIC               = 0x00C60A06,

      GPIO_102_GPIO102                = 0x00C60C00,
      GPIO_102_EM2A4                  = 0x00C60C03,
      GPIO_102_EQEP2S                 = 0x00C60C05,
      GPIO_102_SPICLKC                = 0x00C60C06,

      GPIO_103_GPIO103                = 0x00C60E00,
      GPIO_103_EM2A5                  = 0x00C60E03,
      GPIO_103_EQEP2I                 = 0x00C60E05,
      GPIO_103_SPISTEC                = 0x00C60E06,

      GPIO_104_GPIO104                = 0x00C61000,
      GPIO_104_SDAA                   = 0x00C61001,
      GPIO_104_EM2A6                  = 0x00C61003,
      GPIO_104_EQEP3A                 = 0x00C61005,
      GPIO_104_SCITXDD                = 0x00C61006,

      GPIO_105_GPIO105                = 0x00C61200,
      GPIO_105_SCLA                   = 0x00C61201,
      GPIO_105_EM2A7                  = 0x00C61203,
      GPIO_105_EQEP3B                 = 0x00C61205,
      GPIO_105_SCIRXDD                = 0x00C61206,

      GPIO_106_GPIO106                = 0x00C61400,
      GPIO_106_EM2A8                  = 0x00C61403,
      GPIO_106_EQEP3S                 = 0x00C61405,
      GPIO_106_SCITXDC                = 0x00C61406,

      GPIO_107_GPIO107                = 0x00C61600,
      GPIO_107_EM2A9                  = 0x00C61603,
      GPIO_107_EQEP3I                 = 0x00C61605,
      GPIO_107_SCIRXDC                = 0x00C61606,

      GPIO_108_GPIO108                = 0x00C61800,
      GPIO_108_EM2A10                 = 0x00C61803,

      GPIO_109_GPIO109                = 0x00C61A00,
      GPIO_109_EM2A11                 = 0x00C61A03,

      GPIO_110_GPIO110                = 0x00C61C00,
      GPIO_110_EM2WAIT                = 0x00C61C03,

      GPIO_111_GPIO111                = 0x00C61E00,
      GPIO_111_EM2BA0                 = 0x00C61E03,

      GPIO_112_GPIO112                = 0x00C80000,
      GPIO_112_EM2BA1                 = 0x00C80003,

      GPIO_113_GPIO113                = 0x00C80200,
      GPIO_113_EM2CAS                 = 0x00C80203,

      GPIO_114_GPIO114                = 0x00C80400,
      GPIO_114_EM2RAS                 = 0x00C80403,

      GPIO_115_GPIO115                = 0x00C80600,
      GPIO_115_EM2CS0N                = 0x00C80603,

      GPIO_116_GPIO116                = 0x00C80800,
      GPIO_116_EM2CS2N                = 0x00C80803,

      GPIO_117_GPIO117                = 0x00C80A00,
      GPIO_117_EM2SDCKE               = 0x00C80A03,

      GPIO_118_GPIO118                = 0x00C80C00,
      GPIO_118_EM2CLK                 = 0x00C80C03,

      GPIO_119_GPIO119                = 0x00C80E00,
      GPIO_119_EM2RNW                 = 0x00C80E03,

      GPIO_120_GPIO120                = 0x00C81000,
      GPIO_120_EM2WEN                 = 0x00C81003,
      GPIO_120_USB0PFLT               = 0x00C8100F,

      GPIO_121_GPIO121                = 0x00C81200,
      GPIO_121_EM2OEN                 = 0x00C81203,
      GPIO_121_USB0EPEN               = 0x00C8120F,

      GPIO_122_GPIO122                = 0x00C81400,
      GPIO_122_SPISIMOC               = 0x00C81406,
      GPIO_122_SD1_D1                 = 0x00C81407,
      GPIO_122_ODISCHRGVBUS           = 0x00C8140F,

      GPIO_123_GPIO123                = 0x00C81600,
      GPIO_123_SPISOMIC               = 0x00C81606,
      GPIO_123_SD1_C1                 = 0x00C81607,
      GPIO_123_OCHRGVBUS              = 0x00C8160F,

      GPIO_124_GPIO124                = 0x00C81800,
      GPIO_124_SPICLKC                = 0x00C81806,
      GPIO_124_SD1_D2                 = 0x00C81807,
      GPIO_124_ODMPULLDN              = 0x00C8180F,

      GPIO_125_GPIO125                = 0x00C81A00,
      GPIO_125_SPISTEC                = 0x00C81A06,
      GPIO_125_SD1_C2                 = 0x00C81A07,
      GPIO_125_ODPPULLDN              = 0x00C81A0F,

      GPIO_126_GPIO126                = 0x00C81C00,
      GPIO_126_SD1_D3                 = 0x00C81C07,
      GPIO_126_OLSD_2_N               = 0x00C81C0F,

      GPIO_127_GPIO127                = 0x00C81E00,
      GPIO_127_SD1_C3                 = 0x00C81E07,
      GPIO_127_OLSD_1_N               = 0x00C81E0F,

      GPIO_128_GPIO128                = 0x01060000,
      GPIO_128_SD1_D4                 = 0x01060007,
      GPIO_128_OIDPULLUP              = 0x0106000F,

      GPIO_129_GPIO129                = 0x01060200,
      GPIO_129_SD1_C4                 = 0x01060207,
      GPIO_129_OSPEED                 = 0x0106020F,

      GPIO_130_GPIO130                = 0x01060400,
      GPIO_130_SD2_D1                 = 0x01060407,
      GPIO_130_OSUSPEND               = 0x0106040F,

      GPIO_131_GPIO131                = 0x01060600,
      GPIO_131_SD2_C1                 = 0x01060607,
      GPIO_131_OOE                    = 0x0106060F,

      GPIO_132_GPIO132                = 0x01060800,
      GPIO_132_SD2_D2                 = 0x01060807,
      GPIO_132_ODMSE1                 = 0x0106080F,

      GPIO_133_GPIO133                = 0x01060A00,
      GPIO_133_SD2_C2                 = 0x01060A07,
      GPIO_133_ODPDAT                 = 0x01060A0F,

      GPIO_134_GPIO134                = 0x01060C00,
      GPIO_134_SD2_D3                 = 0x01060C07,
      GPIO_134_IVBUSVALID             = 0x01060C0F,

      GPIO_135_GPIO135                = 0x01060E00,
      GPIO_135_SCITXDA                = 0x01060E06,
      GPIO_135_SD2_C3                 = 0x01060E07,

      GPIO_136_GPIO136                = 0x01061000,
      GPIO_136_SCIRXDA                = 0x01061006,
      GPIO_136_SD2_D4                 = 0x01061007,

      GPIO_137_GPIO137                = 0x01061200,
      GPIO_137_SCITXDB                = 0x01061206,
      GPIO_137_SD2_C4                 = 0x01061207,

      GPIO_138_GPIO138                = 0x01061400,
      GPIO_138_SCIRXDB                = 0x01061406,

      GPIO_139_GPIO139                = 0x01061600,
      GPIO_139_SCIRXDC                = 0x01061606,

      GPIO_140_GPIO140                = 0x01061800,
      GPIO_140_SCITXDC                = 0x01061806,

      GPIO_141_GPIO141                = 0x01061A00,
      GPIO_141_SCIRXDD                = 0x01061A06,

      GPIO_142_GPIO142                = 0x01061C00,
      GPIO_142_SCITXDD                = 0x01061C06,

      GPIO_143_GPIO143                = 0x01061E00,

      GPIO_144_GPIO144                = 0x01080000,

      GPIO_145_GPIO145                = 0x01080200,
      GPIO_145_EPWM1A                 = 0x01080201,

      GPIO_146_GPIO146                = 0x01080400,
      GPIO_146_EPWM1B                 = 0x01080401,

      GPIO_147_GPIO147                = 0x01080600,
      GPIO_147_EPWM2A                 = 0x01080601,

      GPIO_148_GPIO148                = 0x01080800,
      GPIO_148_EPWM2B                 = 0x01080801,

      GPIO_149_GPIO149                = 0x01080A00,
      GPIO_149_EPWM3A                 = 0x01080A01,

      GPIO_150_GPIO150                = 0x01080C00,
      GPIO_150_EPWM3B                 = 0x01080C01,

      GPIO_151_GPIO151                = 0x01080E00,
      GPIO_151_EPWM4A                 = 0x01080E01,

      GPIO_152_GPIO152                = 0x01081000,
      GPIO_152_EPWM4B                 = 0x01081001,

      GPIO_153_GPIO153                = 0x01081200,
      GPIO_153_EPWM5A                 = 0x01081201,

      GPIO_154_GPIO154                = 0x01081400,
      GPIO_154_EPWM5B                 = 0x01081401,

      GPIO_155_GPIO155                = 0x01081600,
      GPIO_155_EPWM6A                 = 0x01081601,

      GPIO_156_GPIO156                = 0x01081800,
      GPIO_156_EPWM6B                 = 0x01081801,

      GPIO_157_GPIO157                = 0x01081A00,
      GPIO_157_EPWM7A                 = 0x01081A01,

      GPIO_158_GPIO158                = 0x01081C00,
      GPIO_158_EPWM7B                 = 0x01081C01,

      GPIO_159_GPIO159                = 0x01081E00,
      GPIO_159_EPWM8A                 = 0x01081E01,

      GPIO_160_GPIO160                = 0x01460000,
      GPIO_160_EPWM8B                 = 0x01460001,

      GPIO_161_GPIO161                = 0x01460200,
      GPIO_161_EPWM9A                 = 0x01460201,

      GPIO_162_GPIO162                = 0x01460400,
      GPIO_162_EPWM9B                 = 0x01460401,

      GPIO_163_GPIO163                = 0x01460600,
      GPIO_163_EPWM10A                = 0x01460601,

      GPIO_164_GPIO164                = 0x01460800,
      GPIO_164_EPWM10B                = 0x01460801,

      GPIO_165_GPIO165                = 0x01460A00,
      GPIO_165_EPWM11A                = 0x01460A01,

      GPIO_166_GPIO166                = 0x01460C00,
      GPIO_166_EPWM11B                = 0x01460C01,

      GPIO_167_GPIO167                = 0x01460E00,
      GPIO_167_EPWM12A                = 0x01460E01,

      GPIO_168_GPIO168                = 0x01461000,
      GPIO_168_EPWM12B                = 0x01461001,
	}
	return pin_map[pin]
end

return P
