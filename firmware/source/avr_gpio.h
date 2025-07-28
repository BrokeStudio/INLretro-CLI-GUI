#ifndef _avr_gpio_h
#define _avr_gpio_h

#include <avr/io.h>

//AVR GPIO ports are 8bits wide
//Use this type when need an int to hold pin mask
#define	GPIO_PinMask	uint8_t

#define     __IO    volatile             /*!< Defines 'read / write' permissions */

/** 
  * @brief General Purpose I/O
  */

typedef struct
{
  __IO uint8_t PIN;       /*!< GPIO port output type register,              Address offset: 0x00      */
  __IO uint8_t DDR;          /*!< GPIO port input data register,               Address offset: 0x01      */
  __IO uint8_t PORT;          /*!< GPIO port output data register,              Address offset: 0x02      */
} GPIO_TypeDef;

#define REGISTER_BASE           ((uint16_t)0x0000U)

/*!< GPIO peripherals */
#define GPIOA_BASE            (REGISTER_BASE + 0x0020)
#define GPIOB_BASE            (REGISTER_BASE + 0x0023)
#define GPIOC_BASE            (REGISTER_BASE + 0x0026)
#define GPIOD_BASE            (REGISTER_BASE + 0x0029)


#define GPIOA               ((GPIO_TypeDef *) GPIOA_BASE)
#define GPIOB               ((GPIO_TypeDef *) GPIOB_BASE)
#define GPIOC               ((GPIO_TypeDef *) GPIOC_BASE)
#define GPIOD               ((GPIO_TypeDef *) GPIOD_BASE)

//#define GPIO_MODER_MODER0_Pos           (0U)                                   
//#define GPIO_MODER_MODER0_Msk           (0x3U << GPIO_MODER_MODER0_Pos)        /*!< 0x00000003 */
//#define GPIO_MODER_MODER0               GPIO_MODER_MODER0_Msk                  

#endif
