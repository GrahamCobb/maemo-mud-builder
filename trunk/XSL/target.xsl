<?xml version="1.0" encoding="ISO-8859-1"?>
<xsl:transform version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform">

<xsl:param name="target">chinook</xsl:param>

<!-- Handle target attribute, if present -->
<xsl:template match="*[@target]">
 <!-- Only copy the node if the target attribute matches -->
 <xsl:if test="@target=$target">
  <xsl:copy>
    <!-- Copy all the attributes except the target attribute -->
    <xsl:for-each select="@*">
       <xsl:if test="name()!='target'">
	<xsl:attribute name="{name()}"><xsl:value-of select="."/></xsl:attribute>
       </xsl:if>
    </xsl:for-each>
    <!-- And recurse -->
    <xsl:apply-templates/>
  </xsl:copy>
 </xsl:if>
</xsl:template>

<!-- If no target attribute, recurse to the next level -->
<xsl:template match="*[not(@target)]">
  <xsl:copy>
    <xsl:for-each select="@*">
	<xsl:attribute name="{name()}"><xsl:value-of select="."/></xsl:attribute>
    </xsl:for-each>
    <xsl:apply-templates/>
  </xsl:copy>
</xsl:template>

</xsl:transform>
