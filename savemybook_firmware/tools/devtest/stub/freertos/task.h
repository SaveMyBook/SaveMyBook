#pragma once
#include "freertos/FreeRTOS.h"
typedef struct HostTask *TaskHandle_t;
TaskHandle_t xTaskGetCurrentTaskHandle(void);
BaseType_t xTaskNotifyGive(TaskHandle_t task);
uint32_t ulTaskNotifyTake(BaseType_t clear, TickType_t ticks);
void vTaskDelay(TickType_t ticks);
