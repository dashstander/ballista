package org.ballistacompute.optimizer

import org.ballistacompute.logical.*
import java.lang.IllegalStateException

class ProjectionPushDownRule : OptimizerRule {

    override fun optimize(plan: LogicalPlan): LogicalPlan {
        return pushDown(plan, mutableSetOf())
    }

    private fun pushDown(plan: LogicalPlan,
                         columnNames: MutableSet<String>): LogicalPlan {

        println("pushDown() plan=$plan")
        return when (plan) {
            is Projection -> {
                extractColumns(plan.expr, plan.input, columnNames)
                val input = pushDown(plan.input, columnNames)
                Projection(input, plan.expr)
            }
            is Selection -> {
                extractColumns(plan.expr, plan.input, columnNames)
                val input = pushDown(plan.input, columnNames)
                Selection(input, plan.expr)
            }
            is Aggregate -> {
                extractColumns(plan.groupExpr, plan.input, columnNames)
                extractColumns(plan.aggregateExpr.map { it.expr }, plan.input, columnNames)
                val input = pushDown(plan.input, columnNames)
                Aggregate(input, plan.groupExpr, plan.aggregateExpr)
            }
            is Scan -> {
                val validFieldNames = plan.dataSource.schema().fields.map { it.name }.toSet()
                val pushDown = validFieldNames.filter { columnNames.contains(it) }.toSet().sorted()
                Scan(plan.name, plan.dataSource, pushDown)
            }
            else -> TODO(plan.javaClass.name)
        }
    }

}