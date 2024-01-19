local P = {}

function P.getPinSettings(pin)
	pin_map = {
	  GPIO_0_GPIO0                    = 0x00060000,
	  GPIO_0_EPWM1_A                  = 0x00060001,
	  GPIO_0_I2CA_SDA                 = 0x00060006,
	
	  GPIO_1_GPIO1                    = 0x00060200,
	  GPIO_1_EPWM1_B                  = 0x00060201,
	  GPIO_1_I2CA_SCL                 = 0x00060206,
	
	  GPIO_2_GPIO2                    = 0x00060400,
	  GPIO_2_EPWM2_A                  = 0x00060401,
	  GPIO_2_OUTPUTXBAR1              = 0x00060405,
	  GPIO_2_PMBUSA_SDA               = 0x00060406,
	  GPIO_2_SCIA_TX                  = 0x00060409,
	  GPIO_2_FSIRXA_D1                = 0x0006040A,
	
	  GPIO_3_GPIO3                    = 0x00060600,
	  GPIO_3_EPWM2_B                  = 0x00060601,
	  GPIO_3_OUTPUTXBAR2              = 0x00060602,
	  GPIO_3_PMBUSA_SCL               = 0x00060606,
	  GPIO_3_SPIA_CLK                 = 0x00060607,
	  GPIO_3_SCIA_RX                  = 0x00060609,
	  GPIO_3_FSIRXA_D0                = 0x0006060A,
	
	  GPIO_4_GPIO4                    = 0x00060800,
	  GPIO_4_EPWM3_A                  = 0x00060801,
	  GPIO_4_OUTPUTXBAR3              = 0x00060805,
	  GPIO_4_CANA_TX                  = 0x00060806,
	  GPIO_4_FSIRXA_CLK               = 0x0006080A,
	
	  GPIO_5_GPIO5                    = 0x00060A00,
	  GPIO_5_EPWM3_B                  = 0x00060A01,
	  GPIO_5_OUTPUTXBAR3              = 0x00060A03,
	  GPIO_5_CANA_RX                  = 0x00060A06,
	  GPIO_5_SPIA_STE                 = 0x00060A07,
	  GPIO_5_FSITXA_D1                = 0x00060A09,
	
	  GPIO_6_GPIO6                    = 0x00060C00,
	  GPIO_6_EPWM4_A                  = 0x00060C01,
	  GPIO_6_OUTPUTXBAR4              = 0x00060C02,
	  GPIO_6_SYNCOUT                  = 0x00060C03,
	  GPIO_6_EQEP1_A                  = 0x00060C05,
	  GPIO_6_CANB_TX                  = 0x00060C06,
	  GPIO_6_SPIB_SOMI                = 0x00060C07,
	  GPIO_6_FSITXA_D0                = 0x00060C09,
	
	  GPIO_7_GPIO7                    = 0x00060E00,
	  GPIO_7_EPWM4_B                  = 0x00060E01,
	  GPIO_7_OUTPUTXBAR5              = 0x00060E03,
	  GPIO_7_EQEP1_B                  = 0x00060E05,
	  GPIO_7_CANB_RX                  = 0x00060E06,
	  GPIO_7_SPIB_SIMO                = 0x00060E07,
	  GPIO_7_FSITXA_CLK               = 0x00060E09,
	
	  GPIO_8_GPIO8                    = 0x00061000,
	  GPIO_8_EPWM5_A                  = 0x00061001,
	  GPIO_8_CANB_TX                  = 0x00061002,
	  GPIO_8_ADCSOCAO                 = 0x00061003,
	  GPIO_8_EQEP1_STROBE             = 0x00061005,
	  GPIO_8_SCIA_TX                  = 0x00061006,
	  GPIO_8_SPIA_SIMO                = 0x00061007,
	  GPIO_8_I2CA_SCL                 = 0x00061009,
	  GPIO_8_FSITXA_D1                = 0x0006100A,
	
	  GPIO_9_GPIO9                    = 0x00061200,
	  GPIO_9_EPWM5_B                  = 0x00061201,
	  GPIO_9_SCIB_TX                  = 0x00061202,
	  GPIO_9_OUTPUTXBAR6              = 0x00061203,
	  GPIO_9_EQEP1_INDEX              = 0x00061205,
	  GPIO_9_SCIA_RX                  = 0x00061206,
	  GPIO_9_SPIA_CLK                 = 0x00061207,
	  GPIO_9_FSITXA_D0                = 0x0006120A,
	
	  GPIO_10_GPIO10                  = 0x00061400,
	  GPIO_10_EPWM6_A                 = 0x00061401,
	  GPIO_10_CANB_RX                 = 0x00061402,
	  GPIO_10_ADCSOCBO                = 0x00061403,
	  GPIO_10_EQEP1_A                 = 0x00061405,
	  GPIO_10_SCIB_TX                 = 0x00061406,
	  GPIO_10_SPIA_SOMI               = 0x00061407,
	  GPIO_10_I2CA_SDA                = 0x00061409,
	  GPIO_10_FSITXA_CLK              = 0x0006140A,
	
	  GPIO_11_GPIO11                  = 0x00061600,
	  GPIO_11_EPWM6_B                 = 0x00061601,
	  GPIO_11_SCIB_RX                 = 0x00061602,
	  GPIO_11_OUTPUTXBAR7             = 0x00061603,
	  GPIO_11_EQEP1_B                 = 0x00061605,
	  GPIO_11_SPIA_STE                = 0x00061607,
	  GPIO_11_FSIRXA_D1               = 0x00061609,
	
	  GPIO_12_GPIO12                  = 0x00061800,
	  GPIO_12_EPWM7_A                 = 0x00061801,
	  GPIO_12_CANB_TX                 = 0x00061802,
	  GPIO_12_EQEP1_STROBE            = 0x00061805,
	  GPIO_12_SCIB_TX                 = 0x00061806,
	  GPIO_12_PMBUSA_CTL              = 0x00061807,
	  GPIO_12_FSIRXA_D0               = 0x00061809,
	
	  GPIO_13_GPIO13                  = 0x00061A00,
	  GPIO_13_EPWM7_B                 = 0x00061A01,
	  GPIO_13_CANB_RX                 = 0x00061A02,
	  GPIO_13_EQEP1_INDEX             = 0x00061A05,
	  GPIO_13_SCIB_RX                 = 0x00061A06,
	  GPIO_13_PMBUSA_ALERT            = 0x00061A07,
	  GPIO_13_FSIRXA_CLK              = 0x00061A09,
	
	  GPIO_14_GPIO14                  = 0x00061C00,
	  GPIO_14_EPWM8_A                 = 0x00061C01,
	  GPIO_14_SCIB_TX                 = 0x00061C02,
	  GPIO_14_OUTPUTXBAR3             = 0x00061C06,
	  GPIO_14_PMBUSA_SDA              = 0x00061C07,
	  GPIO_14_SPIB_CLK                = 0x00061C09,
	  GPIO_14_EQEP2_A                 = 0x00061C0A,
	
	  GPIO_15_GPIO15                  = 0x00061E00,
	  GPIO_15_EPWM8_B                 = 0x00061E01,
	  GPIO_15_SCIB_RX                 = 0x00061E02,
	  GPIO_15_OUTPUTXBAR4             = 0x00061E06,
	  GPIO_15_PMBUSA_SCL              = 0x00061E07,
	  GPIO_15_SPIB_STE                = 0x00061E09,
	  GPIO_15_EQEP2_B                 = 0x00061E0A,
	
	  GPIO_16_GPIO16                  = 0x00080000,
	  GPIO_16_SPIA_SIMO               = 0x00080001,
	  GPIO_16_CANB_TX                 = 0x00080002,
	  GPIO_16_OUTPUTXBAR7             = 0x00080003,
	  GPIO_16_EPWM5_A                 = 0x00080005,
	  GPIO_16_SCIA_TX                 = 0x00080006,
	  GPIO_16_SD1_D1                  = 0x00080007,
	  GPIO_16_EQEP1_STROBE            = 0x00080009,
	  GPIO_16_PMBUSA_SCL              = 0x0008000A,
	  GPIO_16_XCLKOUT                 = 0x0008000B,
	
	  GPIO_17_GPIO17                  = 0x00080200,
	  GPIO_17_SPIA_SOMI               = 0x00080201,
	  GPIO_17_CANB_RX                 = 0x00080202,
	  GPIO_17_OUTPUTXBAR8             = 0x00080203,
	  GPIO_17_EPWM5_B                 = 0x00080205,
	  GPIO_17_SCIA_RX                 = 0x00080206,
	  GPIO_17_SD1_C1                  = 0x00080207,
	  GPIO_17_EQEP1_INDEX             = 0x00080209,
	  GPIO_17_PMBUSA_SDA              = 0x0008020A,
	
	  GPIO_18_GPIO18_X2               = 0x00080400,
	  GPIO_18_SPIA_CLK                = 0x00080401,
	  GPIO_18_SCIB_TX                 = 0x00080402,
	  GPIO_18_CANA_RX                 = 0x00080403,
	  GPIO_18_EPWM6_A                 = 0x00080405,
	  GPIO_18_I2CA_SCL                = 0x00080406,
	  GPIO_18_SD1_D2                  = 0x00080407,
	  GPIO_18_EQEP2_A                 = 0x00080409,
	  GPIO_18_PMBUSA_CTL              = 0x0008040A,
	  GPIO_18_XCLKOUT                 = 0x0008040B,
	
	  GPIO_20_GPIO20                  = 0x00080800,
	
	  GPIO_21_GPIO21                  = 0x00080A00,
	
	  GPIO_22_GPIO22_VFBSW            = 0x00080C00,
	  GPIO_22_EQEP1_STROBE            = 0x00080C01,
	  GPIO_22_SCIB_TX                 = 0x00080C03,
	  GPIO_22_SPIB_CLK                = 0x00080C06,
	  GPIO_22_SD1_D4                  = 0x00080C07,
	  GPIO_22_LINA_TX                 = 0x00080C09,
	
	  GPIO_23_GPIO23_VSW              = 0x00080E00,
	  GPIO_23_GPIO23                  = 0x00080E04,
	
	  GPIO_24_GPIO24                  = 0x00081000,
	  GPIO_24_OUTPUTXBAR1             = 0x00081001,
	  GPIO_24_EQEP2_A                 = 0x00081002,
	  GPIO_24_EPWM8_A                 = 0x00081005,
	  GPIO_24_SPIB_SIMO               = 0x00081006,
	  GPIO_24_SD1_D1                  = 0x00081007,
	  GPIO_24_PMBUSA_SCL              = 0x0008100A,
	  GPIO_24_SCIA_TX                 = 0x0008100B,
	  GPIO_24_ERRORSTS                = 0x0008100D,
	
	  GPIO_25_GPIO25                  = 0x00081200,
	  GPIO_25_OUTPUTXBAR2             = 0x00081201,
	  GPIO_25_EQEP2_B                 = 0x00081202,
	  GPIO_25_SPIB_SOMI               = 0x00081206,
	  GPIO_25_SD1_C1                  = 0x00081207,
	  GPIO_25_FSITXA_D1               = 0x00081209,
	  GPIO_25_PMBUSA_SDA              = 0x0008120A,
	  GPIO_25_SCIA_RX                 = 0x0008120B,
	
	  GPIO_26_GPIO26                  = 0x00081400,
	  GPIO_26_OUTPUTXBAR3             = 0x00081401,
	  GPIO_26_EQEP2_INDEX             = 0x00081402,
	  GPIO_26_SPIB_CLK                = 0x00081406,
	  GPIO_26_SD1_D2                  = 0x00081407,
	  GPIO_26_FSITXA_D0               = 0x00081409,
	  GPIO_26_PMBUSA_CTL              = 0x0008140A,
	  GPIO_26_I2CA_SDA                = 0x0008140B,
	
	  GPIO_27_GPIO27                  = 0x00081600,
	  GPIO_27_OUTPUTXBAR4             = 0x00081601,
	  GPIO_27_EQEP2_STROBE            = 0x00081602,
	  GPIO_27_SPIB_STE                = 0x00081606,
	  GPIO_27_SD1_C2                  = 0x00081607,
	  GPIO_27_FSITXA_CLK              = 0x00081609,
	  GPIO_27_PMBUSA_ALERT            = 0x0008160A,
	  GPIO_27_I2CA_SCL                = 0x0008160B,
	
	  GPIO_28_GPIO28                  = 0x00081800,
	  GPIO_28_SCIA_RX                 = 0x00081801,
	  GPIO_28_EPWM7_A                 = 0x00081803,
	  GPIO_28_OUTPUTXBAR5             = 0x00081805,
	  GPIO_28_EQEP1_A                 = 0x00081806,
	  GPIO_28_SD1_D3                  = 0x00081807,
	  GPIO_28_EQEP2_STROBE            = 0x00081809,
	  GPIO_28_LINA_TX                 = 0x0008180A,
	  GPIO_28_SPIB_CLK                = 0x0008180B,
	  GPIO_28_ERRORSTS                = 0x0008180D,
	
	  GPIO_29_GPIO29                  = 0x00081A00,
	  GPIO_29_SCIA_TX                 = 0x00081A01,
	  GPIO_29_EPWM7_B                 = 0x00081A03,
	  GPIO_29_OUTPUTXBAR6             = 0x00081A05,
	  GPIO_29_EQEP1_B                 = 0x00081A06,
	  GPIO_29_SD1_C3                  = 0x00081A07,
	  GPIO_29_EQEP2_INDEX             = 0x00081A09,
	  GPIO_29_LINA_RX                 = 0x00081A0A,
	  GPIO_29_SPIB_STE                = 0x00081A0B,
	  GPIO_29_ERRORSTS                = 0x00081A0D,
	
	  GPIO_30_GPIO30                  = 0x00081C00,
	  GPIO_30_CANA_RX                 = 0x00081C01,
	  GPIO_30_SPIB_SIMO               = 0x00081C03,
	  GPIO_30_OUTPUTXBAR7             = 0x00081C05,
	  GPIO_30_EQEP1_STROBE            = 0x00081C06,
	  GPIO_30_SD1_D4                  = 0x00081C07,
	
	  GPIO_31_GPIO31                  = 0x00081E00,
	  GPIO_31_CANA_TX                 = 0x00081E01,
	  GPIO_31_SPIB_SOMI               = 0x00081E03,
	  GPIO_31_OUTPUTXBAR8             = 0x00081E05,
	  GPIO_31_EQEP1_INDEX             = 0x00081E06,
	  GPIO_31_SD1_C4                  = 0x00081E07,
	  GPIO_31_FSIRXA_D1               = 0x00081E09,
	
	  GPIO_32_GPIO32                  = 0x00460000,
	  GPIO_32_I2CA_SDA                = 0x00460001,
	  GPIO_32_SPIB_CLK                = 0x00460003,
	  GPIO_32_EPWM8_B                 = 0x00460005,
	  GPIO_32_LINA_TX                 = 0x00460006,
	  GPIO_32_SD1_D3                  = 0x00460007,
	  GPIO_32_FSIRXA_D0               = 0x00460009,
	  GPIO_32_CANA_TX                 = 0x0046000A,
	
	  GPIO_33_GPIO33                  = 0x00460200,
	  GPIO_33_I2CA_SCL                = 0x00460201,
	  GPIO_33_SPIB_STE                = 0x00460203,
	  GPIO_33_OUTPUTXBAR4             = 0x00460205,
	  GPIO_33_LINA_RX                 = 0x00460206,
	  GPIO_33_SD1_C3                  = 0x00460207,
	  GPIO_33_FSIRXA_CLK              = 0x00460209,
	  GPIO_33_CANA_RX                 = 0x0046020A,
	
	  GPIO_34_GPIO34                  = 0x00460400,
	  GPIO_34_OUTPUTXBAR1             = 0x00460401,
	  GPIO_34_PMBUSA_SDA              = 0x00460406,
	
	  GPIO_35_GPIO35                  = 0x00460600,
	  GPIO_35_SCIA_RX                 = 0x00460601,
	  GPIO_35_I2CA_SDA                = 0x00460603,
	  GPIO_35_CANA_RX                 = 0x00460605,
	  GPIO_35_PMBUSA_SCL              = 0x00460606,
	  GPIO_35_LINA_RX                 = 0x00460607,
	  GPIO_35_EQEP1_A                 = 0x00460609,
	  GPIO_35_PMBUSA_CTL              = 0x0046060A,
	  GPIO_35_TDI                     = 0x0046060F,
	
	  GPIO_37_GPIO37                  = 0x00460A00,
	  GPIO_37_OUTPUTXBAR2             = 0x00460A01,
	  GPIO_37_I2CA_SCL                = 0x00460A03,
	  GPIO_37_SCIA_TX                 = 0x00460A05,
	  GPIO_37_CANA_TX                 = 0x00460A06,
	  GPIO_37_LINA_TX                 = 0x00460A07,
	  GPIO_37_EQEP1_B                 = 0x00460A09,
	  GPIO_37_PMBUSA_ALERT            = 0x00460A0A,
	  GPIO_37_TDO                     = 0x00460A0F,
	
	  GPIO_39_GPIO39                  = 0x00460E00,
	  GPIO_39_CANB_RX                 = 0x00460E06,
	  GPIO_39_FSIRXA_CLK              = 0x00460E07,
	
	  GPIO_40_GPIO40                  = 0x00461000,
	  GPIO_40_PMBUSA_SDA              = 0x00461006,
	  GPIO_40_FSIRXA_D0               = 0x00461007,
	  GPIO_40_SCIB_TX                 = 0x00461009,
	  GPIO_40_EQEP1_A                 = 0x0046100A,
	
	  GPIO_41_GPIO41                  = 0x00461200,
	
	  GPIO_42_GPIO42                  = 0x00461400,
	
	  GPIO_43_GPIO43                  = 0x00461600,
	
	  GPIO_44_GPIO44                  = 0x00461800,
	
	  GPIO_45_GPIO45                  = 0x00461A00,
	
	  GPIO_46_GPIO46                  = 0x00461C00,
	
	  GPIO_47_GPIO47                  = 0x00461E00,
	
	  GPIO_48_GPIO48                  = 0x00480000,
	
	  GPIO_49_GPIO49                  = 0x00480200,
	
	  GPIO_50_GPIO50                  = 0x00480400,
	
	  GPIO_51_GPIO51                  = 0x00480600,
	
	  GPIO_52_GPIO52                  = 0x00480800,
	
	  GPIO_53_GPIO53                  = 0x00480A00,
	
	  GPIO_54_GPIO54                  = 0x00480C00,
	
	  GPIO_55_GPIO55                  = 0x00480E00,
	
	  GPIO_56_GPIO56                  = 0x00481000,
	  GPIO_56_SPIA_CLK                = 0x00481001,
	  GPIO_56_EQEP2_STROBE            = 0x00481005,
	  GPIO_56_SCIB_TX                 = 0x00481006,
	  GPIO_56_SD1_D3                  = 0x00481007,
	  GPIO_56_SPIB_SIMO               = 0x00481009,
	  GPIO_56_EQEP1_A                 = 0x0048100B,
	
	  GPIO_57_GPIO57                  = 0x00481200,
	  GPIO_57_SPIA_STE                = 0x00481201,
	  GPIO_57_EQEP2_INDEX             = 0x00481205,
	  GPIO_57_SCIB_RX                 = 0x00481206,
	  GPIO_57_SD1_C3                  = 0x00481207,
	  GPIO_57_SPIB_SOMI               = 0x00481209,
	  GPIO_57_EQEP1_B                 = 0x0048120B,
	
	  GPIO_58_GPIO58                  = 0x00481400,
	  GPIO_58_OUTPUTXBAR1             = 0x00481405,
	  GPIO_58_SPIB_CLK                = 0x00481406,
	  GPIO_58_SD1_D4                  = 0x00481407,
	  GPIO_58_LINA_TX                 = 0x00481409,
	  GPIO_58_CANB_TX                 = 0x0048140A,
	  GPIO_58_EQEP1_STROBE            = 0x0048140B,
	
	  GPIO_59_GPIO59                  = 0x00481600,
	  GPIO_59_OUTPUTXBAR2             = 0x00481605,
	  GPIO_59_SPIB_STE                = 0x00481606,
	  GPIO_59_SD1_C4                  = 0x00481607,
	  GPIO_59_LINA_RX                 = 0x00481609,
	  GPIO_59_CANB_RX                 = 0x0048160A,
	  GPIO_59_EQEP1_INDEX             = 0x0048160B,
	
	  GPIO_247_GPIO247                = 0x01C80E00,
	
	  GPIO_246_GPIO246                = 0x01C80C00,
	
	  GPIO_230_GPIO230                = 0x01C60C00,
	
	  GPIO_241_GPIO241                = 0x01C80200,
	
	  GPIO_242_GPIO242                = 0x01C80400,
	
	  GPIO_237_GPIO237                = 0x01C61A00,
	
	  GPIO_224_GPIO224                = 0x01C60000,
	
	  GPIO_244_GPIO244                = 0x01C80800,
	
	  GPIO_226_GPIO226                = 0x01C60400,
	
	  GPIO_233_GPIO233                = 0x01C61200,
	
	  GPIO_239_GPIO239                = 0x01C61E00,
	
	  GPIO_228_GPIO228                = 0x01C60800,
	
	  GPIO_232_GPIO232                = 0x01C61000,
	
	  GPIO_231_GPIO231                = 0x01C60E00,
	
	  GPIO_227_GPIO227                = 0x01C60600,
	
	  GPIO_245_GPIO245                = 0x01C80A00,
	
	  GPIO_235_GPIO235                = 0x01C61600,
	
	  GPIO_236_GPIO236                = 0x01C61800,
	
	  GPIO_234_GPIO234                = 0x01C61400,
	
	  GPIO_243_GPIO243                = 0x01C80600,
	
	  GPIO_225_GPIO225                = 0x01C60200,
	
	  GPIO_238_GPIO238                = 0x01C61C00,
	
	  GPIO_229_GPIO229                = 0x01C60A00,
	
	  GPIO_240_GPIO240                = 0x01C80000,
	}
	return pin_map[pin]
end

return P
